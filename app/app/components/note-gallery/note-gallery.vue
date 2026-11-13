<template>
  <div class="note-gallery">
    <!-- 只有一张：直接展示图片，点击后由 el-image 打开大图预览 -->
    <el-image
      v-if="images.length === 1"
      class="note-gallery__img"
      :src="images[0]"
      :alt="altText"
      fit="cover"
      :preview-src-list="images"
      :initial-index="0"
      preview-teleported
      hide-on-click-modal
    />

    <!-- 多张：Element Plus 轮播；每张都带上整组图片的大图预览 -->
    <el-carousel
      v-else-if="images.length > 1"
      ref="carouselRef"
      height="100%"
      :autoplay="false"
      :initial-index="index"
      @change="handleChange"
    >
      <el-carousel-item v-for="(image, i) in images" :key="`${image}-${i}`">
        <el-image
          class="note-gallery__img"
          :src="image"
          :alt="t('gallery.altIndex', { alt: altText, index: i + 1 })"
          fit="cover"
          :preview-src-list="images"
          :initial-index="i"
          preview-teleported
          hide-on-click-modal
        />
      </el-carousel-item>
    </el-carousel>
  </div>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue'

const props = withDefaults(
  defineProps<{
    images: string[]
    index?: number
    alt?: string
  }>(),
  { index: 0, alt: '' },
)
const emit = defineEmits<{ 'update:index': [value: number] }>()

const { t } = useI18n()
/** 没传 alt 时用通用文案，随语言切换 */
const altText = computed(() => props.alt || t('gallery.alt'))

// el-carousel 的实例类型没有直接导出，这里只用到 setActiveItem
const carouselRef = ref<any>(null)

// 标题切换时把轮播拨到对应图片
watch(
  () => props.index,
  (value) => {
    carouselRef.value?.setActiveItem?.(value)
  },
)

// 用户手动切换时回传当前下标
function handleChange(value: number) {
  if (value !== props.index) {
    emit('update:index', value)
  }
}
</script>

<style scoped>
.note-gallery {
  width: 100%;
  height: 100%;
  overflow: hidden;
}

/* el-carousel 根节点默认没有高度，height 只作用在内部 container 上，
   需要显式撑满，否则图片区高度会塌成 0 */
.note-gallery :deep(.el-carousel) {
  height: 100%;
}

/* el-image 的根节点和内部 img 都撑满容器，保持原来的 cover 效果 */
.note-gallery :deep(.el-image) {
  display: block;
  width: 100%;
  height: 100%;
  cursor: zoom-in;
}

.note-gallery :deep(.el-image__inner) {
  display: block;
  width: 100%;
  height: 100%;
  object-fit: cover;
}

/* 多图轮播时，指示器放在底部内侧 */
.note-gallery :deep(.el-carousel__indicators--inside) {
  bottom: 8px;
}
</style>
