# 内容详情页的图片上传：后台新增 / 编辑内容时，把图片存到 public/uploads/notes 并返回可访问地址。
module Api
  module V1
    module Admin
      class NoteImagesController < Api::V1::BaseController
        MAX_SIZE = 5.megabytes

        # POST /api/v1/admin/note_images
        def create
          # 新增或编辑内容都需要能上传图片
          authorize_any!("content:note:create", "content:note:update")

          file = params[:file]
          raise ActionController::ParameterMissing, :file if file.blank?
          return render_error(:unprocessable_entity, "图片大小不能超过 5MB") if file.size > MAX_SIZE

          extension = UploadStorage.image_extension(file)
          return render_error(:unprocessable_entity, "仅支持 PNG / JPEG / WebP 图片") if extension.nil?

          url = UploadStorage.store(file, extension: extension, scope: "notes")
          render json: { url: url }, status: :created
        end
      end
    end
  end
end
