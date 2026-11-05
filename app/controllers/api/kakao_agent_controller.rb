class Api::KakaoAgentController < ApplicationController
  skip_before_action :require_admin
  skip_forgery_protection
  before_action :authenticate_device

  def configuration
    @device.update!(last_seen_at: Time.current)
    rooms = @device.account.kakao_rooms.where(active: true).order(:last_collected_at, :id).limit(@device.max_rooms_per_run)
    render json: { account: @device.account.name, rooms: rooms.pluck(:name), collect_start_hour: @device.collect_start_hour, collect_end_hour: @device.collect_end_hour, allow_focus: @device.allow_focus, limit: 30 }
  end

  def messages
    room = @device.account.kakao_rooms.find_by(name: params[:room], active: true)
    return render json: { error: "등록되지 않은 방" }, status: :unprocessable_entity unless room
    entries = params[:messages]
    return render json: { error: "메시지는 200개 이하의 배열이어야 합니다" }, status: :unprocessable_entity unless entries.is_a?(Array) && entries.size <= 200
    unless entries.all? { |entry| entry.is_a?(ActionController::Parameters) && entry[:body].is_a?(String) && entry[:body].strip.present? && entry[:body].length <= 5000 }
      return render json: { error: "내용은 1~5000자여야 합니다" }, status: :unprocessable_entity
    end
    now = Time.current
    rows = entries.map do |entry|
      message = entry.permit(:author, :body, :date, :time_raw).to_h
      { account_id: @device.account_id, kakao_room_id: room.id, kakao_device_id: @device.id,
        author: message["author"], body: message["body"].unicode_normalize(:nfc).strip,
        sent_on: safe_date(message["date"]), time_raw: message["time_raw"], sent_at: KakaoMessage.message_time(message["date"], message["time_raw"]),
        digest: KakaoMessage.message_digest(room.name, message), created_at: now, updated_at: now }
    end
    created = 0
    KakaoMessage.transaction do
      created = KakaoMessage.insert_all(rows, unique_by: [ :account_id, :digest ], returning: %w[id]).rows.size if rows.any?
      room.update!(last_collected_at: now, last_message_count: entries.size)
      @device.update!(last_seen_at: now, last_collected_at: now)
    end
    render json: { received: entries.size, created: created, duplicates: entries.size - created }
  end

  def report_status
    attributes = { last_seen_at: Time.current, last_error: nil }
    attributes.merge!(last_error: params[:error].to_s.truncate(5000), last_error_at: Time.current) unless ActiveModel::Type::Boolean.new.cast(params[:ok])
    @device.update!(attributes)
    render json: { ok: true }
  end

  private

  def authenticate_device
    token = request.headers["Authorization"].to_s.match(/\ABearer (\S+)\z/)&.captures&.first
    @device = KakaoDevice.authenticate(token)
    render json: { error: "기기 인증이 필요합니다" }, status: :unauthorized unless @device
  end

  def safe_date(value)
    Date.iso8601(value.to_s)
  rescue ArgumentError
    nil
  end
end
