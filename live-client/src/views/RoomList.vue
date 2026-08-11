<template>
  <div class="room-list">
    <div class="list-header">
      <h2>热门直播</h2>
      <div class="filter">
        <select v-model="selectedCategory">
          <option value="">全部分类</option>
          <option value="游戏">游戏</option>
          <option value="娱乐">娱乐</option>
          <option value="教育">教育</option>
          <option value="其他">其他</option>
        </select>
      </div>
    </div>

    <div v-if="rooms.length === 0" class="empty">
      <p>暂无直播间</p>
      <button @click="createDemoRoom">创建一个演示直播间</button>
    </div>

    <div v-else class="room-grid">
      <div 
        v-for="room in filteredRooms" 
        :key="room.id" 
        class="room-card"
        @click="$emit('enter-room', room.id)"
      >
        <div class="room-cover">
          <img v-if="room.cover" :src="room.cover" :alt="room.title" />
          <div v-else class="cover-placeholder">{{ room.title.charAt(0) }}</div>
          <div class="live-badge" v-if="room.isLive">
            <span class="live-dot"></span>
            <span>直播中</span>
          </div>
          <div class="viewer-count" v-if="room.isLive">
            <span>👁</span>
            <span>{{ room.viewerCount || 0 }}</span>
          </div>
        </div>
        <div class="room-info">
          <h3 class="room-title">{{ room.title }}</h3>
          <div class="room-meta">
            <span class="category">{{ room.category }}</span>
            <span class="status" :class="room.isLive ? 'online' : 'offline'">
              {{ room.isLive ? '直播中' : '未开播' }}
            </span>
          </div>
          <div class="room-actions" @click.stop>
            <button class="share-action-btn" @click="shareRoom(room)">分享</button>
          </div>
        </div>
      </div>
    </div>

    <!-- 分享弹窗 -->
    <div v-if="showShareModal" class="share-modal" @click.self="closeShareModal">
      <div class="share-modal-content">
        <h3>分享直播间</h3>
        <p class="share-desc">复制下方链接分享给朋友</p>
        <div class="share-link-box">
          <input
            v-model="currentShareUrl"
            readonly
            class="share-link-input"
          />
          <button class="copy-btn" @click="copyShareLink">复制</button>
        </div>
        <div class="share-options">
          <button class="share-option-btn" @click="shareToWeChat">微信</button>
          <button class="share-option-btn" @click="shareToQQ">QQ</button>
          <button class="share-option-btn" @click="shareToWeibo">微博</button>
        </div>
        <button class="close-share-btn" @click="closeShareModal">关闭</button>
        <p v-if="copySuccess" class="copy-tip">链接已复制到剪贴板</p>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'

const emit = defineEmits(['enter-room'])

const rooms = ref([])
const selectedCategory = ref('')
let timer = null

const showShareModal = ref(false)
const currentShareUrl = ref('')
const copySuccess = ref(false)

const filteredRooms = computed(() => {
  if (!selectedCategory.value) return rooms.value
  return rooms.value.filter(r => r.category === selectedCategory.value)
})

async function fetchRooms() {
  try {
    const res = await fetch('/api/rooms')
    const data = await res.json()
    if (data.success) {
      rooms.value = data.data
    }
  } catch (e) {
    console.error('获取直播间列表失败:', e)
  }
}

async function createDemoRoom() {
  try {
    const res = await fetch('/api/rooms', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        title: '演示直播间 - 点击观看',
        category: '其他',
        description: '这是一个演示直播间，可以配置视频循环推流实现伪直播'
      })
    })
    const data = await res.json()
    if (data.success) {
      fetchRooms()
    }
  } catch (e) {
    console.error('创建直播间失败:', e)
  }
}

function shareRoom(room) {
  currentShareUrl.value = `${window.location.origin}/room/${room.id}`
  showShareModal.value = true
  copySuccess.value = false
}

function closeShareModal() {
  showShareModal.value = false
}

function copyShareLink() {
  const input = document.querySelector('.share-link-input')
  if (input) {
    input.select()
    document.execCommand('copy')
    copySuccess.value = true
    setTimeout(() => {
      copySuccess.value = false
    }, 2000)
  }
}

function shareToWeChat() {
  alert('请复制链接后在微信中粘贴发送给朋友')
}

function shareToQQ() {
  alert('请复制链接后在QQ中粘贴发送给朋友')
}

function shareToWeibo() {
  alert('请复制链接后在微博中分享')
}

onMounted(() => {
  fetchRooms()
  timer = setInterval(fetchRooms, 3000)
})

onUnmounted(() => {
  if (timer) clearInterval(timer)
})
</script>

<style scoped>
.room-list { max-width: 1200px; margin: 0 auto; }
.list-header {
  display: flex; justify-content: space-between; align-items: center;
  margin-bottom: 20px;
}
.list-header h2 { color: #333; }
.filter select {
  padding: 8px 12px; border: 1px solid #ddd; border-radius: 8px;
  font-size: 14px;
}
.empty {
  text-align: center; padding: 60px 20px; color: #999;
}
.empty button {
  margin-top: 16px; padding: 10px 24px; border: none; border-radius: 8px;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white; cursor: pointer; font-size: 14px;
}
.room-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(240px, 1fr));
  gap: 20px;
}
.room-card {
  background: white; border-radius: 12px; overflow: hidden;
  cursor: pointer; transition: transform 0.3s, box-shadow 0.3s;
  box-shadow: 0 2px 8px rgba(0,0,0,0.06);
}
.room-card:hover {
  transform: translateY(-4px);
  box-shadow: 0 8px 24px rgba(0,0,0,0.12);
}
.room-cover {
  position: relative; width: 100%; padding-top: 56.25%;
  background: #f0f0f0;
}
.room-cover img {
  position: absolute; top: 0; left: 0; width: 100%; height: 100%;
  object-fit: cover;
}
.cover-placeholder {
  position: absolute; top: 0; left: 0; width: 100%; height: 100%;
  display: flex; align-items: center; justify-content: center;
  font-size: 48px; color: #fff;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
}
.live-badge {
  position: absolute; top: 12px; left: 12px;
  display: flex; align-items: center; gap: 4px;
  padding: 4px 10px; background: #ff4757; color: white;
  border-radius: 4px; font-size: 12px; font-weight: bold;
}
.live-dot {
  width: 6px; height: 6px; background: white; border-radius: 50%;
  animation: pulse 1s infinite;
}
@keyframes pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.5; }
}
.viewer-count {
  position: absolute; bottom: 12px; right: 12px;
  display: flex; align-items: center; gap: 4px;
  padding: 4px 10px; background: rgba(0,0,0,0.6); color: white;
  border-radius: 4px; font-size: 12px;
}
.room-info { padding: 12px 16px; }
.room-title {
  font-size: 15px; color: #333; margin-bottom: 8px;
  overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
}
.room-meta {
  display: flex; justify-content: space-between; align-items: center;
  font-size: 12px; color: #999;
}
.category {
  padding: 2px 8px; background: #f0f0f0; border-radius: 10px;
}
.status.online { color: #4ade80; }
.status.offline { color: #999; }
.room-actions {
  margin-top: 12px;
  display: flex;
  justify-content: flex-end;
}
.share-action-btn {
  padding: 6px 16px;
  border: 1px solid #667eea;
  background: transparent;
  color: #667eea;
  border-radius: 6px;
  cursor: pointer;
  font-size: 13px;
  transition: all 0.2s;
}
.share-action-btn:hover {
  background: #667eea;
  color: white;
}
.share-modal {
  position: fixed;
  inset: 0;
  background: rgba(0,0,0,0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}
.share-modal-content {
  background: white;
  border-radius: 12px;
  padding: 24px;
  width: 90%;
  max-width: 400px;
  text-align: center;
}
.share-modal-content h3 {
  margin: 0 0 8px 0;
  color: #333;
}
.share-desc {
  color: #666;
  font-size: 14px;
  margin-bottom: 16px;
}
.share-link-box {
  display: flex;
  gap: 8px;
  margin-bottom: 16px;
}
.share-link-input {
  flex: 1;
  padding: 10px 12px;
  border: 1px solid #ddd;
  border-radius: 8px;
  font-size: 13px;
  color: #333;
  background: #f8f8f8;
}
.copy-btn {
  padding: 10px 20px;
  background: #667eea;
  color: white;
  border: none;
  border-radius: 8px;
  cursor: pointer;
  font-size: 13px;
}
.copy-btn:hover {
  background: #5568d3;
}
.share-options {
  display: flex;
  gap: 12px;
  justify-content: center;
  margin-bottom: 16px;
}
.share-option-btn {
  padding: 8px 20px;
  border: 1px solid #e0e0e0;
  background: white;
  border-radius: 8px;
  cursor: pointer;
  font-size: 13px;
  transition: all 0.2s;
}
.share-option-btn:hover {
  background: #f5f5f5;
  border-color: #667eea;
  color: #667eea;
}
.close-share-btn {
  padding: 8px 32px;
  background: #f0f0f0;
  border: none;
  border-radius: 8px;
  cursor: pointer;
  font-size: 13px;
  color: #666;
}
.close-share-btn:hover {
  background: #e0e0e0;
}
.copy-tip {
  color: #4ade80;
  font-size: 13px;
  margin-top: 12px;
}
</style>
