# 内容详情页的图片上传：后台新增 / 编辑内容时，把图片存到 public/uploads/notes 并返回可访问地址。
module Api
  module V1
    module Admin
      class NoteImagesController < Api::V1::BaseController
        MAX_SIZE = 5.megabytes
        # 与头像上传保持一致的格式白名单，并据此决定落盘后缀
        EXTENSIONS = { "image/png" => "png", "image/jpeg" => "jpg", "image/webp" => "webp" }.freeze
        UPLOAD_DIR = Rails.root.join("public", "uploads", "notes")

        # POST /api/v1/admin/note_images
        def create
          # 新增或编辑内容都需要能上传图片
          authorize_any!("content:note:create", "content:note:update")

          file = params[:file]
          raise ActionController::ParameterMissing, :file if file.blank?

          extension = EXTENSIONS[file.content_type]
          return render_error(:unprocessable_entity, "仅支持 PNG / JPEG / WebP 图片") if extension.nil?
          return render_error(:unprocessable_entity, "图片大小不能超过 5MB") if file.size > MAX_SIZE

          FileUtils.mkdir_p(UPLOAD_DIR)
          # 随机文件名，避免同名覆盖和用户可控的文件名
          filename = "#{SecureRandom.uuid}.#{extension}"
          File.binwrite(UPLOAD_DIR.join(filename), file.read)

          render json: { url: "#{public_origin}/uploads/notes/#{filename}" }, status: :created
        end

        private

        def public_origin
          ENV.fetch("PUBLIC_API_ORIGIN", "http://localhost:3000")
        end
      end
    end
  end
end
