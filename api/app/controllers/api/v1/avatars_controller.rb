# 当前登录用户的头像：上传 / 删除。都是操作「自己」，所以不需要额外权限。
#
# 头像不是必填项：没上传时 avatar_url 为 nil，前端会回退到「首字母 + 底色」的展示方式。
module Api
  module V1
    class AvatarsController < BaseController
      MAX_SIZE = 2.megabytes
      # 只接受常见图片格式，并据此决定落盘的后缀
      EXTENSIONS = { "image/png" => "png", "image/jpeg" => "jpg", "image/webp" => "webp" }.freeze
      UPLOAD_DIR = Rails.root.join("public", "uploads", "avatars")

      # POST /api/v1/profile/avatar
      def create
        file = params[:file]
        raise ActionController::ParameterMissing, :file if file.blank?

        extension = EXTENSIONS[file.content_type]
        return render_error(:unprocessable_entity, "仅支持 PNG / JPEG / WebP 图片") if extension.nil?
        return render_error(:unprocessable_entity, "图片大小不能超过 2MB") if file.size > MAX_SIZE

        FileUtils.mkdir_p(UPLOAD_DIR)
        # 用随机名落盘，避免同名覆盖和用户可控的文件名
        filename = "#{SecureRandom.uuid}.#{extension}"
        File.binwrite(UPLOAD_DIR.join(filename), file.read)

        # 换成新头像前先把旧文件删掉，避免目录里堆积
        remove_avatar_file
        current_user.update!(avatar_url: "#{public_origin}/uploads/avatars/#{filename}")

        render json: UserSerializer.render(current_user.reload)
      end

      # DELETE /api/v1/profile/avatar
      def destroy
        remove_avatar_file
        current_user.update!(avatar_url: nil)

        render json: UserSerializer.render(current_user.reload)
      end

      private

      # 落盘的是「绝对地址」，这样后台（走 Vite 代理）和内容社区（直连 api）都能直接当 img src 用
      def public_origin
        ENV.fetch("PUBLIC_API_ORIGIN", "http://localhost:3000")
      end

      def remove_avatar_file
        return if current_user.avatar_url.blank?

        path = UPLOAD_DIR.join(File.basename(current_user.avatar_url))
        File.delete(path) if File.exist?(path)
      end
    end
  end
end
