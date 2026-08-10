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
        </div>
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
</style>
