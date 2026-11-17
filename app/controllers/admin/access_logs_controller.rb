module Admin
  class AccessLogsController < ApplicationController
    include PersonalDataAccessLogging

    def index
      @from = filter_date(:from)
      @to = filter_date(:to)
      @screen = params[:screen].presence
      logs = AccessLog.all
      logs = logs.where(created_at: @from.in_time_zone.beginning_of_day..) if @from
      logs = logs.where("created_at < ?", (@to + 1.day).in_time_zone.beginning_of_day) if @to
      logs = logs.where(screen: @screen) if @screen
      @screens = AccessLog.distinct.order(:screen).pluck(:screen)
      @total_count = logs.count
      @page = params[:page].to_i.clamp(1, Float::INFINITY)
      @total_pages = (@total_count / 50.0).ceil
      @access_logs = logs.order(created_at: :desc, id: :desc).offset((@page - 1) * 50).limit(50).to_a
      log_personal_data_access(screen: "접속기록 조회")
    end

    private

    def filter_date(key)
      Date.iso8601(params[key]) if params[key].present?
    rescue ArgumentError, TypeError
      nil
    end
  end
end
