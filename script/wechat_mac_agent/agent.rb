#!/usr/bin/env ruby
require "json"
require "net/http"
require "open3"
require "optparse"
require "fileutils"
require "time"
require "base64"

module WechatMacAgent
  class Api
    def initialize(url:, token:, transport: nil)
      @base = URI(url)
      raise "HTTPS 서버 URL이 필요합니다" unless @base.scheme == "https" || (@base.scheme == "http" && %w[localhost 127.0.0.1].include?(@base.host))
      @token = token
      @transport = transport
    end

    def call(method, path, payload = nil)
      uri = URI.join(@base.to_s, "/api/wechat_agent/#{path}")
      request = (method == :get ? Net::HTTP::Get : Net::HTTP::Post).new(uri)
      request["Authorization"] = "Bearer #{@token}"
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(payload) if payload
      response = if @transport
        @transport.call(uri, request)
      else
        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 5, read_timeout: 10) { |http| http.request(request) }
      end
      raise "API HTTP #{response.code}" unless response.code.to_i.between?(200, 299)
      response.body.to_s.empty? ? nil : JSON.parse(response.body)
    end
  end

  class RateLimit
    def initialize(timestamps = [])
      @timestamps = timestamps
    end

    def allowed?(now)
      @timestamps.reject! { |value| value <= now - 3600 }
      @timestamps.size < 30 && (@timestamps.empty? || now - @timestamps.last >= 20)
    end

    def record(now)
      @timestamps << now
    end
  end

  class Notifications
    APP_ID = "com.tencent.xinWeChat".freeze

    def initialize(path)
      @path = path
    end

    def self.parse(rec_id, data)
      require "sqlite3"
      # usernoted stores a binary plist. plutil handles both binary and XML plists.
      json, _error, status = Open3.capture3("/usr/bin/plutil", "-convert", "json", "-o", "-", "-", stdin_data: data)
      raise "알림 plist 파싱 실패" unless status.success?
      payload = JSON.parse(json)
      request = payload.fetch("req", {})
      title = request["titl"] || request["title"]
      body = request["body"]
      return unless title.is_a?(String) && body.is_a?(String) && !title.empty? && !body.empty?
      { external_key: "notification:#{rec_id}", display_name: title, content: body, received_at: Time.now.utc.iso8601 }
    end

    def poll
      require "sqlite3"
      db = SQLite3::Database.new(@path, flags: SQLite3::Constants::Open::READONLY)
      db.busy_timeout = 1000
      db.execute("SELECT record.rec_id, record.data FROM record JOIN app ON record.app_id = app.app_id WHERE app.identifier = ? ORDER BY record.rec_id", [ APP_ID ]).filter_map do |id, data|
        self.class.parse(id, data)
      end
    ensure
      db&.close
    end
  end

  class Desktop
    def send_message(name, content)
      raise "빈 대화방 이름" if name.to_s.strip.empty?
      # Pass values through argv / clipboard, never interpolate user text as AppleScript.
      script = <<~APPLESCRIPT
        on run argv
          set the clipboard to item 1 of argv
          tell application "WeChat" to activate
          delay 1
          tell application "System Events"
            tell process "WeChat"
              keystroke "f" using command down
              delay 1
              keystroke "v" using command down
              delay 2
              key code 36
              delay 2
            end tell
          end tell
        end run
      APPLESCRIPT
      run_script(script, name)
      paste = <<~APPLESCRIPT
        on run argv
          set the clipboard to item 1 of argv
          tell application "System Events"
            tell process "WeChat"
              keystroke "v" using command down
              delay 1
              key code 36
            end tell
          end tell
        end run
      APPLESCRIPT
      run_script(paste, content)
    end

    def run_script(script, value)
      _out, _error, status = Open3.capture3("/usr/bin/osascript", "-e", script, value)
      raise "위챗 앱 조작 실패; 실제 대화방과 발송 여부를 확인하세요" unless status.success?
    end
  end

  class Runner
    def initialize(config, dry_run:, read_only:)
      token, _error, status = Open3.capture3("/usr/bin/security", "find-generic-password", "-s", config.fetch("keychain_service"), "-a", config.fetch("keychain_account"), "-w")
      raise "키체인 토큰을 읽지 못했습니다" unless status.success? && !token.strip.empty?
      @api = Api.new(url: config.fetch("server_url"), token: token.strip)
      @state_path = File.expand_path(config.fetch("state_path", "~/.local/state/wechat_mac_agent/state.json"))
      @state = File.exist?(@state_path) ? JSON.parse(File.read(@state_path)) : { "received" => [], "attempts" => [], "results" => {} }
      @state["results"] ||= {}
      @limit = RateLimit.new(@state.fetch("attempts"))
      @notifications = Notifications.new(File.expand_path(config.fetch("notification_db", "~/Library/Group Containers/group.com.apple.usernoted/db2/db")))
      @dry_run = dry_run
      @read_only = read_only
    end

    def tick
      @api.call(:post, "heartbeat")
      @notifications.poll.each do |message|
        key = message.fetch(:external_key)
        next if @state.fetch("received").include?(key)
        if @dry_run
          puts "수신 발견: #{key}"
          next
        end
        @api.call(:post, "inbox", message)
        @state.fetch("received") << key
        persist
      end
      return if @read_only
      @api.call(:get, "outbox").each do |message|
        id = message.fetch("id").to_s
        if @state["results"].key?(id)
          @api.call(:post, "outbox/#{id}/result", @state["results"][id])
          next
        end
        break unless @limit.allowed?(Time.now.to_f)
        if @dry_run
          puts "발송 예정 id=#{id}"
          next
        end
        # Persist before UI automation: a crash must never silently resend.
        @limit.record(Time.now.to_f)
        @state["results"][id] = { ok: false, error: "발송 중 중단됨; 실제 위챗 확인 필요" }
        persist
        begin
          Desktop.new.send_message(message.fetch("display_name"), message.fetch("content"))
          @state["results"][id] = { ok: true }
        rescue StandardError
          @state["results"][id] = { ok: false, error: "앱 조작 실패; 실제 위챗 확인 필요" }
        end
        persist
        @api.call(:post, "outbox/#{id}/result", @state["results"][id])
      end
    end

    def persist
      FileUtils.mkdir_p(File.dirname(@state_path), mode: 0700)
      temporary = "#{@state_path}.tmp"
      File.write(temporary, JSON.generate(@state), perm: 0600)
      File.rename(temporary, @state_path)
    end
  end
end

if $PROGRAM_NAME == __FILE__
  options = { dry_run: false, read_only: true }
  OptionParser.new do |parser|
    parser.on("--config PATH") { |path| options[:config] = path }
    parser.on("--dry-run") { options[:dry_run] = true }
    parser.on("--read-only") { options[:read_only] = true }
    parser.on("--send") { options[:read_only] = false }
  end.parse!
  config = JSON.parse(File.read(options.fetch(:config)))
  raise "설정 파일에 토큰을 저장하지 마세요" if config.keys.any? { |key| key.match?(/token|secret/i) }
  runner = WechatMacAgent::Runner.new(config, dry_run: options[:dry_run], read_only: options[:read_only])
  lock_path = File.expand_path(config.fetch("state_path", "~/.local/state/wechat_mac_agent/state.json")) + ".lock"
  FileUtils.mkdir_p(File.dirname(lock_path), mode: 0700)
  File.open(lock_path, File::RDWR | File::CREAT, 0600) do |lock|
    raise "이미 실행 중입니다" unless lock.flock(File::LOCK_EX | File::LOCK_NB)
    loop do
      begin
        runner.tick
      rescue StandardError => error
        warn "에이전트 처리 실패: #{error.class} (권한·서버·알림 DB를 확인하세요)"
      end
      sleep 20
    end
  end
end
