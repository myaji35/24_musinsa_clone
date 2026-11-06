class Api::KakaoBridge::V1::AgentController < ApplicationController
  skip_before_action :require_admin
  skip_forgery_protection
  before_action :authenticate_device

  def configuration
    @device.update!(last_seen_at: Time.current)
    rooms = @device.account.kakao_rooms.where(active: true).order(:id)
    render json: {
      protocol: 1, server_time: Time.current.iso8601,
      rooms: rooms.map { |room| { id: room.id, name: room.name, aliases: room.alias_names } },
      realtime: { enabled: @device.realtime_enabled, poll_seconds: 60 },
      backfill: { enabled: @device.backfill_enabled, window: @device.backfill_window, time_zone: @device.time_zone,
                  max_rooms: @device.backfill_max_rooms, limit_per_room: @device.backfill_limit_per_room },
      open_window: { enabled: @device.open_window_enabled, poll_seconds: @device.open_window_poll_seconds, limit_per_room: 50 }
    }
  end

  def messages
    room = @device.account.kakao_rooms.where(active: true).detect { |candidate| candidate.name == params[:room] || candidate.alias_names.include?(params[:room]) }
    return render json: { error: "등록되지 않은 방" }, status: :unprocessable_entity unless room
    entries = params[:messages]
    unless entries.is_a?(Array) && entries.size <= 200 && entries.all? { |entry| entry.is_a?(ActionController::Parameters) }
      return render json: { error: "메시지는 200개 이하의 배열이어야 합니다" }, status: :unprocessable_entity
    end
    render json: KakaoMessage.ingest!(device: @device, room: room, source: params[:source], messages: entries.map(&:to_unsafe_h))
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def report_status
    attributes = params.permit(:agent_version, :ok, :last_realtime_at, :last_backfill_at, permissions: [ :full_disk_access, :accessibility ]).to_h
    attributes.merge!(last_seen_at: Time.current, last_error: nil)
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
end
