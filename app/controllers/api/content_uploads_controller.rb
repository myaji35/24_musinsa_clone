module Api
  class ContentUploadsController < ApplicationController
    skip_before_action :require_admin, :verify_authenticity_token
    before_action :authenticate_upload

    def create
      file = params[:file]
      unless file.is_a?(ActionDispatch::Http::UploadedFile)
        return render json: { errors: [ "파일이 필요합니다" ] }, status: :unprocessable_entity
      end
      digest = Digest::SHA256.file(file.tempfile.path).hexdigest
      if params[:sha256].present? && params[:sha256] != digest
        return render json: { errors: [ "sha256이 파일과 일치하지 않습니다" ] }, status: :unprocessable_entity
      end
      character = if params[:character_handle].present?
        Character.find_by(handle: params[:character_handle])
      else
        Character.find_by(id: params[:character_id])
      end
      upload = ContentUpload.new(product_id: params[:product_id], character: character,
        kind: params[:kind], slot: params[:slot], source_row: params[:source_row], sha256: digest)
      upload.file.attach(file)
      # 중복이어도 잘못된 상품/모델/형식 요청은 성공으로 처리하지 않는다.
      upload.valid?
      errors = upload.errors.reject { |error| error.attribute == :sha256 && error.type == :taken }.map(&:full_message)
      return render json: { errors: errors }, status: :unprocessable_entity if errors.any?

      ContentUpload.transaction do
        existing = ContentUpload.find_by(sha256: digest)
        return render json: { duplicate: true, id: existing.id }, status: :ok if existing

        ContentUpload.where(product_id: upload.product_id, character_id: upload.character_id,
          kind: upload.kind, slot: upload.slot).each(&:destroy!)
        upload.save!
      end
      render json: { duplicate: false, id: upload.id }, status: :created
    rescue ActiveRecord::RecordInvalid => error
      render json: { errors: error.record.errors.full_messages }, status: :unprocessable_entity
    rescue ActiveRecord::RecordNotUnique
      existing = ContentUpload.find_by(sha256: digest)
      if existing
        render json: { duplicate: true, id: existing.id }, status: :ok
      else
        render json: { errors: [ "같은 컷이 업로드 중입니다. 다시 시도해 주세요" ] }, status: :unprocessable_entity
      end
    end

    private

    def authenticate_upload
      expected = ENV["CONTENT_UPLOAD_TOKEN"]
      return render json: { error: "upload token not configured" }, status: :service_unavailable if expected.blank?

      provided = request.headers["Authorization"].to_s.delete_prefix("Bearer ")
      unless request.headers["Authorization"].to_s.start_with?("Bearer ") &&
          ActiveSupport::SecurityUtils.secure_compare(provided, expected)
        render json: { error: "unauthorized" }, status: :unauthorized
      end
    end
  end
end
