# 当前登录用户的头像：上传 / 删除。都是操作「自己」，所以不需要额外权限。
#
# 头像不是必填项：没上传时 avatar_url 为 nil，前端会回退到「首字母 + 底色」的展示方式。
module Api
  module V1
    class AvatarsController < BaseController
      MAX_SIZE = 2.megabytes

      # POST /api/v1/profile/avatar
      def create
        file = params[:file]
        raise ActionController::ParameterMissing, :file if file.blank?
        return render_error(:unprocessable_content, "图片大小不能超过 2MB") if file.size > MAX_SIZE

        # 用文件头判断真实格式，不信任客户端传的 content-type
        extension = UploadStorage.image_extension(file)
        return render_error(:unprocessable_content, "仅支持 PNG / JPEG / WebP 图片") if extension.nil?

        # 换成新头像前先把旧文件删掉，避免目录里堆积
        remove_avatar_file
        url = UploadStorage.store(file, extension: extension, scope: "avatars")
        current_user.update!(avatar_url: url)

        render json: UserSerializer.render(current_user.reload)
      end

      # DELETE /api/v1/profile/avatar
      def destroy
        remove_avatar_file
        current_user.update!(avatar_url: nil)

        render json: UserSerializer.render(current_user.reload)
      end

      private

      # 本地存储直接删文件；S3 由存储桶生命周期或 CDN 策略清理
      def remove_avatar_file
        UploadStorage.delete(current_user.avatar_url)
      end
    end
  end
end
