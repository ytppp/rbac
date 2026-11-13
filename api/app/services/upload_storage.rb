# 图片存储：本地开发写 public/uploads；上线通过 UPLOAD_DRIVER=s3 切到对象存储 + CDN。
#
# 本地（默认）：
#   UPLOAD_DRIVER=local
#   PUBLIC_UPLOAD_BASE=http://localhost:3000   # 对外访问前缀，可换成 CDN 域名
# 上线：
#   UPLOAD_DRIVER=s3
#   S3_BUCKET / S3_REGION / S3_PUBLIC_BASE     # 需在 Gemfile 安装 aws-sdk-s3
class UploadStorage
  # 只接受这三种图片格式，后缀由文件头决定，不信任客户端传的 content-type
  MIME_TYPES = { "png" => "image/png", "jpg" => "image/jpeg", "webp" => "image/webp" }.freeze

  class << self
    # 读取文件头判断真实类型，返回扩展名；不是受支持的图片返回 nil
    def image_extension(io)
      head = io.read(12).to_s.b
      io.rewind

      bytes = head.bytes
      return "png" if bytes[0, 8] == [ 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A ]
      return "jpg" if bytes[0, 3] == [ 0xFF, 0xD8, 0xFF ]
      return "webp" if head[0, 4] == "RIFF" && head[8, 4] == "WEBP"

      nil
    end

    # 落盘并返回可访问地址
    def store(file, extension:, scope:)
      filename = "#{SecureRandom.uuid}.#{extension}"
      driver == "s3" ? store_to_s3(file, filename, extension: extension, scope: scope) : store_local(file, filename, scope: scope)
    end

    # 删除旧文件：本地直接删；S3 交给存储桶生命周期或 CDN 缓存策略
    def delete(url)
      return if url.blank? || driver == "s3"

      relative = url.to_s.sub(%r{\A#{Regexp.escape(public_base)}/?}, "")
      path = Rails.root.join("public", relative)
      File.delete(path) if File.exist?(path)
    rescue StandardError => e
      Rails.logger.warn("[UploadStorage] 删除文件失败：#{e.message}")
    end

    def driver
      ENV.fetch("UPLOAD_DRIVER", "local")
    end

    def public_base
      ENV.fetch("PUBLIC_UPLOAD_BASE", ENV.fetch("PUBLIC_API_ORIGIN", "http://localhost:3000")).sub(%r{/+\z}, "")
    end

    private

    def store_local(file, filename, scope:)
      dir = Rails.root.join("public", "uploads", scope)
      FileUtils.mkdir_p(dir)
      File.binwrite(dir.join(filename), file.read)
      "#{public_base}/uploads/#{scope}/#{filename}"
    end

    def store_to_s3(file, filename, extension:, scope:)
      require "aws-sdk-s3"

      key = "#{scope}/#{filename}"
      Aws::S3::Client.new(region: ENV.fetch("S3_REGION", "ap-east-1")).put_object(
        bucket: ENV.fetch("S3_BUCKET"),
        key: key,
        body: file.read,
        content_type: MIME_TYPES.fetch(extension)
      )
      "#{ENV.fetch('S3_PUBLIC_BASE').sub(%r{/+\z}, '')}/#{key}"
    end
  end
end
