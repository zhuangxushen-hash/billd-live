<template>
  <div class="dashboard">
    <el-row :gutter="20">
      <el-col :span="6">
        <el-card class="stat-card">
          <div class="stat-content">
            <div class="stat-icon" style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);">
              <el-icon :size="32"><VideoCamera /></el-icon>
            </div>
            <div class="stat-info">
              <p class="stat-value">{{ stats.totalRooms }}</p>
              <p class="stat-label">直播间总数</p>
            </div>
          </div>
        </el-card>
      </el-col>
      
      <el-col :span="6">
        <el-card class="stat-card">
          <div class="stat-content">
            <div class="stat-icon" style="background: linear-gradient(135deg, #ff6b6b 0%, #ee5a6f 100%);">
              <el-icon :size="32"><Promotion /></el-icon>
            </div>
            <div class="stat-info">
              <p class="stat-value">{{ stats.liveRooms }}</p>
              <p class="stat-label">直播中</p>
            </div>
          </div>
        </el-card>
      </el-col>
      
      <el-col :span="6">
        <el-card class="stat-card">
          <div class="stat-content">
            <div class="stat-icon" style="background: linear-gradient(135deg, #51cf66 0%, #40c057 100%);">
              <el-icon :size="32"><View /></el-icon>
            </div>
            <div class="stat-info">
              <p class="stat-value">{{ stats.totalViewers }}</p>
              <p class="stat-label">在线观众</p>
            </div>
          </div>
        </el-card>
      </el-col>
      
      <el-col :span="6">
        <el-card class="stat-card">
          <div class="stat-content">
            <div class="stat-icon" style="background: linear-gradient(135deg, #ffa94d 0%, #ff922b 100%);">
              <el-icon :size="32"><ChatDotRound /></el-icon>
            </div>
            <div class="stat-info">
              <p class="stat-value">{{ stats.totalDanmaku }}</p>
              <p class="stat-label">弹幕总数</p>
            </div>
          </div>
        </el-card>
      </el-col>
    </el-row>

    <el-row :gutter="20" style="margin-top: 20px;">
      <el-col :span="16">
        <el-card>
          <template #header>
            <div class="card-header">
              <span class="title">热门直播间</span>
              <el-button type="primary" size="small" @click="refresh">刷新</el-button>
            </div>
          </template>
          
          <el-table :data="hotRooms" style="width: 100%">
            <el-table-column prop="title" label="直播间" min-width="150">
              <template #default="{ row }">
                <div class="room-info">
                  <span class="room-name">{{ row.title }}</span>
                  <el-tag 
                    :type="row.isLive ? 'success' : 'info'" 
                    size="small"
                  >
                    {{ row.isLive ? '直播中' : '未开播' }}
                  </el-tag>
                </div>
              </template>
            </el-table-column>
            <el-table-column prop="category" label="分类" width="100" />
            <el-table-column prop="viewerCount" label="观众数" width="100">
              <template #default="{ row }">
                {{ row.viewerCount || 0 }}
              </template>
            </el-table-column>
            <el-table-column prop="createdAt" label="创建时间" width="180">
              <template #default="{ row }">
                {{ formatDate(row.createdAt) }}
              </template>
            </el-table-column>
          </el-table>
        </el-card>
      </el-col>
      
      <el-col :span="8">
        <el-card>
          <template #header>
            <div class="card-header">
              <span class="title">系统状态</span>
            </div>
          </template>
          
          <div class="system-status">
            <div class="status-item">
              <span class="status-label">服务状态</span>
              <el-tag type="success">运行中</el-tag>
            </div>
            <div class="status-item">
              <span class="status-label">SRS 流媒体</span>
              <el-tag :type="srsStatus ? 'success' : 'warning'">
                {{ srsStatus ? '已连接' : '未连接' }}
              </el-tag>
            </div>
            <div class="status-item">
              <span class="status-label">FFmpeg 伪直播</span>
              <el-tag :type="ffmpegStatus ? 'success' : 'info'">
                {{ ffmpegStatus ? '运行中' : '未启动' }}
              </el-tag>
            </div>
            <div class="status-item">
              <span class="status-label">运行时长</span>
              <span class="status-value">{{ uptime }}</span>
            </div>
          </div>
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted, computed } from 'vue'

const stats = ref({
  totalRooms: 0,
  liveRooms: 0,
  totalViewers: 0,
  totalDanmaku: 0
})

const hotRooms = ref([])
const srsStatus = ref(false)
const ffmpegStatus = ref(false)
const startTime = ref(Date.now())
let timer = null

const uptime = computed(() => {
  const diff = Math.floor((Date.now() - startTime.value) / 1000)
  const hours = Math.floor(diff / 3600)
  const minutes = Math.floor((diff % 3600) / 60)
  const seconds = diff % 60
  return `${hours}h ${minutes}m ${seconds}s`
})

async function fetchStats() {
  try {
    const res = await fetch('/api/stats')
    const data = await res.json()
    if (data.success) {
      stats.value = data.data
    }
  } catch (e) {
    console.error('获取统计数据失败:', e)
  }
}

async function fetchRooms() {
  try {
    const res = await fetch('/api/rooms')
    const data = await res.json()
    if (data.success) {
      hotRooms.value = data.data.slice(0, 5)
    }
  } catch (e) {
    console.error('获取直播间列表失败:', e)
  }
}

function refresh() {
  fetchStats()
  fetchRooms()
}

function formatDate(dateStr) {
  if (!dateStr) return '-'
  const date = new Date(dateStr)
  return date.toLocaleString('zh-CN')
}

onMounted(() => {
  fetchStats()
  fetchRooms()
  timer = setInterval(() => {
    fetchStats()
    fetchRooms()
  }, 5000)
})

onUnmounted(() => {
  if (timer) clearInterval(timer)
})
</script>

<style scoped>
.dashboard { }
.stat-card {
  border-radius: 12px;
  border: none;
}
.stat-content {
  display: flex;
  align-items: center;
  gap: 16px;
}
.stat-icon {
  width: 56px;
  height: 56px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
}
.stat-value {
  font-size: 28px;
  font-weight: bold;
  color: #333;
  line-height: 1;
}
.stat-label {
  font-size: 14px;
  color: #999;
  margin-top: 4px;
}
.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
.card-header .title {
  font-size: 16px;
  font-weight: bold;
  color: #333;
}
.room-info {
  display: flex;
  align-items: center;
  gap: 8px;
}
.room-name {
  font-weight: 500;
}
.system-status {
  display: flex;
  flex-direction: column;
  gap: 16px;
}
.status-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 12px;
  background: #f8f8f8;
  border-radius: 8px;
}
.status-label {
  color: #666;
}
.status-value {
  font-weight: bold;
  color: #333;
}
</style>
