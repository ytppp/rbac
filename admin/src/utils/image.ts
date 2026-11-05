/**
 * 上传前压缩图片：超大图在浏览器里缩到最大边 maxEdge，再转成 WebP，
 * 避免把手机原图（动辄 5~15MB）直接塞给后端。
 */
interface CompressOptions {
  /** 长边最大像素，默认 2400 */
  maxEdge?: number
  /** 压缩质量 0~1，默认 0.85 */
  quality?: number
  /** 小于该体积且尺寸不超标时跳过压缩，默认 1.5MB */
  minSize?: number
}

const DEFAULT_MAX_EDGE = 2400
const DEFAULT_QUALITY = 0.85
const DEFAULT_MIN_SIZE = 1.5 * 1024 * 1024

function loadImage(file: File): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(file)
    const image = new Image()

    image.onload = () => {
      URL.revokeObjectURL(url)
      resolve(image)
    }
    image.onerror = () => {
      URL.revokeObjectURL(url)
      reject(new Error('图片读取失败'))
    }
    image.src = url
  })
}

function canvasToBlob(
  canvas: HTMLCanvasElement,
  type: string,
  quality: number,
): Promise<Blob | null> {
  return new Promise((resolve) => canvas.toBlob(resolve, type, quality))
}

export async function compressImage(
  file: File,
  options: CompressOptions = {},
): Promise<File> {
  if (!file.type.startsWith('image/')) return file

  const maxEdge = options.maxEdge ?? DEFAULT_MAX_EDGE
  const quality = options.quality ?? DEFAULT_QUALITY
  const minSize = options.minSize ?? DEFAULT_MIN_SIZE

  try {
    const image = await loadImage(file)
    const { naturalWidth: width, naturalHeight: height } = image
    if (!width || !height) return file

    const needsResize = Math.max(width, height) > maxEdge
    // 体积不大、尺寸也不超标时，原样上传
    if (file.size <= minSize && !needsResize) return file

    const scale = Math.min(1, maxEdge / Math.max(width, height))
    const targetWidth = Math.max(1, Math.round(width * scale))
    const targetHeight = Math.max(1, Math.round(height * scale))

    const canvas = document.createElement('canvas')
    canvas.width = targetWidth
    canvas.height = targetHeight

    const context = canvas.getContext('2d')
    if (!context) return file

    context.imageSmoothingEnabled = true
    context.imageSmoothingQuality = 'high'
    context.drawImage(image, 0, 0, targetWidth, targetHeight)

    // 优先 WebP（体积小且保留透明）；浏览器不支持时退回 JPEG
    let blob = await canvasToBlob(canvas, 'image/webp', quality)
    if (!blob) {
      context.globalCompositeOperation = 'destination-over'
      context.fillStyle = '#ffffff'
      context.fillRect(0, 0, targetWidth, targetHeight)
      blob = await canvasToBlob(canvas, 'image/jpeg', quality)
    }

    // 压缩后反而更大就保留原图
    if (!blob || blob.size >= file.size) return file

    const extension = blob.type === 'image/webp' ? 'webp' : 'jpg'
    const name = `${file.name.replace(/\.[^.]+$/, '')}.${extension}`
    return new File([blob], name, { type: blob.type, lastModified: Date.now() })
  } catch {
    // 解码失败时不阻断上传，交给服务端做格式 / 体积校验
    return file
  }
}
