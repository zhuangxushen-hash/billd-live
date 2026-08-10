<template>
  <div class="room-management">
    <el-card>
      <template #header>
        <div class="header">
          <span class="title">直播间管理</span>
          <div>
            <el-input
              v-model="searchKeyword"
              placeholder="搜索直播间"
              style="width: 200px; margin-right: 12px;"
              :prefix-icon="Search"
              clearable
            />
            <el-button type="primary" @click="showCreateDialog = true">
              <el-icon><Plus /></el-icon>
              创建直播间
            </el-button>
          </div>
        </div>
      </template>
      
      <el-table :data="filteredRooms" style="width: 100%">
        <el-table-column prop="id" label="ID" width="60" />
        <el-table-column prop="title" label="直播间标题" min-width="200">
          <template #default="{ row }">
            <div class="room-title-cell">
              <span>{{ row.title }}</span>
              <el-tag 
                :type="row.isLive ? 'success' : 'info'" 
                size="small"
                style="margin-left: 8px;"
              >
                {{ row.isLive ? '直播中' : '未开播' }}
              </el-tag>
            </div>
          </template>
        </el-table-column>
        <el-table-column prop="category" label="分类" width="100">
          <template #default="{ row }">
            <el-tag size="small">{{ row.category }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="viewerCount" label="观众" width="80">
          <template #default="{ row }">
            {{ row.viewerCount || 0 }}
          </template>
        </el-table-column>
        <el-table-column prop="createdAt" label="创建时间" width="170">
          <template #default="{ row }">
            {{ formatDate(row.createdAt) }}
          </template>
        </el-table-column>
        <el-table-column label="操作" width="280" fixed="right">
          <template #default="{ row }">
            <el-button 
              v-if="!row.isLive" 
              type="success" 
              size="small" 
              @click="startStream(row)"
            >
              开始直播
            </el-button>
            <el-button 
              v-else 
              type="warning" 
              size="small" 
              @click="stopStream(row)"
            >
              结束直播
            </el-button>
            <el-button type="primary" size="small" @click="viewStreamUrl(row)">
              推流地址
            </el-button>
            <el-button size="small" @click="editRoom(row)">编辑</el-button>
            <el-button type="danger" size="small" @click="deleteRoom(row)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <el-dialog v-model="showCreateDialog" title="创建直播间" width="500px">
      <el-form :model="createForm" label-width="80px">
        <el-form-item label="直播间标题">
          <el-input v-model="createForm.title" placeholder="请输入直播间标题" />
        </el-form-item>
        <el-form-item label="分类">
          <el-select v-model="createForm.category" placeholder="请选择分类">
            <el-option label="游戏" value="游戏" />
            <el-option label="娱乐" value="娱乐" />
            <el-option label="教育" value="教育" />
            <el-option label="其他" value="其他" />
          </el-select>
        </el-form-item>
        <el-form-item label="描述">
          <el-input 
            v-model="createForm.description" 
            type="textarea" 
            :rows="3"
            placeholder="请输入直播间描述"
          />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showCreateDialog = false">取消</el-button>
        <el-button type="primary" @click="createRoom">创建</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="showUrlDialog" title="推流地址" width="600px">
      <div v-if="currentStreamUrl" class="stream-url-display">
        <div class="url-item">
          <span class="url-label">RTMP 推流地址:</span>
          <el-input v-model="currentStreamUrl.rtmpUrl" readonly>
            <template #append>
              <el-button @click="copyToClipboard(currentStreamUrl.rtmpUrl)">复制</el-button>
            </template>
          </el-input>
        </div>
        <div class="url-item">
          <span class="url-label">HTTP-FLV 拉流地址:</span>
          <el-input v-model="currentStreamUrl.flvUrl" readonly>
            <template #append>
              <el-button @click="copyToClipboard(currentStreamUrl.flvUrl)">复制</el-button>
            </template>
          </el-input>
        </div>
        <div class="url-item">
          <span class="url-label">HLS 拉流地址:</span>
          <el-input v-model="currentStreamUrl.hlsUrl" readonly>
            <template #append>
              <el-button @click="copyToClipboard(currentStreamUrl.hlsUrl)">复制</el-button>
            </template>
          </el-input>
        </div>
        <div class="url-item">
          <span class="url-label">推流密钥:</span>
          <el-input v-model="currentStreamUrl.streamKey" readonly show-password>
            <template #append>
              <el-button @click="copyToClipboard(currentStreamUrl.streamKey)">复制</el-button>
            </template>
          </el-input>
        </div>
        <el-divider />
        <div class="ffmpeg-command">
          <p class="command-label">FFmpeg 伪直播命令:</p>
          <pre class="command-text">{{ ffmpegCommand }}</pre>
          <el-button @click="copyToClipboard(ffmpegCommand)">复制命令</el-button>
        </div>
      </div>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Search } from '@element-plus/icons-vue'

const rooms = ref([])
const searchKeyword = ref('')
const showCreateDialog = ref(false)
const showUrlDialog = ref(false)
const currentStreamUrl = ref(null)
const currentRoomId = ref(null)

const createForm = ref({
  title: '',
  category: '其他',
  description: ''
})

const filteredRooms = computed(() => {
  if (!searchKeyword.value) return rooms.value
  return rooms.value.filter(r => 
    r.title.includes(searchKeyword.value) || 
    r.category.includes(searchKeyword.value)
  )
})

const ffmpegCommand = computed(() => {
  if (!currentStreamUrl.value) return ''
  const url = currentStreamUrl.value.rtmpUrl
  return `ffmpeg -re -stream_loop -1 -i video.mp4 -c copy -f flv "${url}"`
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

async function createRoom() {
  if (!createForm.value.title) {
    ElMessage.warning('请输入直播间标题')
    return
  }
  
  try {
    const res = await fetch('/api/rooms', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(createForm.value)
    })
    const data = await res.json()
    if (data.success) {
      ElMessage.success('创建成功')
      showCreateDialog.value = false
      createForm.value = { title: '', category: '其他', description: '' }
      fetchRooms()
    }
  } catch (e) {
    ElMessage.error('创建失败')
  }
}

async function startStream(room) {
  try {
    const res = await fetch(`/api/rooms/${room.id}/start`, { method: 'POST' })
    const data = await res.json()
    if (data.success) {
      ElMessage.success('直播已开始')
      fetchRooms()
    }
  } catch (e) {
    ElMessage.error('操作失败')
  }
}

async function stopStream(room) {
  try {
    const res = await fetch(`/api/rooms/${room.id}/stop`, { method: 'POST' })
    const data = await res.json()
    if (data.success) {
      ElMessage.success('直播已结束')
      fetchRooms()
    }
  } catch (e) {
    ElMessage.error('操作失败')
  }
}

async function viewStreamUrl(room) {
  currentRoomId.value = room.id
  try {
    const res = await fetch(`/api/rooms/${room.id}/stream-url`)
    const data = await res.json()
    if (data.success) {
      currentStreamUrl.value = data.data
      showUrlDialog.value = true
    }
  } catch (e) {
    ElMessage.error('获取推流地址失败')
  }
}

function editRoom(room) {
  ElMessage.info(`编辑直播间 ${room.title}`)
}

async function deleteRoom(room) {
  try {
    await ElMessageBox.confirm(
      `确定要删除直播间 "${room.title}" 吗？`,
      '确认删除',
      { type: 'warning' }
    )
    const res = await fetch(`/api/rooms/${room.id}`, { method: 'DELETE' })
    const data = await res.json()
    if (data.success) {
      ElMessage.success('删除成功')
      fetchRooms()
    }
  } catch (e) {
    if (e !== 'cancel') {
      ElMessage.error('删除失败')
    }
  }
}

function copyToClipboard(text) {
  navigator.clipboard.writeText(text).then(() => {
    ElMessage.success('已复制到剪贴板')
  }).catch(() => {
    ElMessage.error('复制失败')
  })
}

function formatDate(dateStr) {
  if (!dateStr) return '-'
  const date = new Date(dateStr)
  return date.toLocaleString('zh-CN')
}

onMounted(() => {
  fetchRooms()
})
</script>

<style scoped>
.room-management { }
.header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
.header .title {
  font-size: 16px;
  font-weight: bold;
  color: #333;
}
.room-title-cell {
  display: flex;
  align-items: center;
}
.stream-url-display {
  display: flex;
  flex-direction: column;
  gap: 12px;
}
.url-item {
  display: flex;
  flex-direction: column;
  gap: 4px;
}
.url-label {
  font-size: 12px;
  color: #666;
}
.ffmpeg-command {
  background: #f8f8f8;
  padding: 12px;
  border-radius: 8px;
}
.command-label {
  font-size: 13px;
  font-weight: bold;
  color: #333;
  margin-bottom: 8px;
}
.command-text {
  background: #1e1e2e;
  color: #cdd6f4;
  padding: 12px;
  border-radius: 8px;
  font-size: 13px;
  font-family: 'Courier New', monospace;
  overflow-x: auto;
  white-space: pre-wrap;
  word-break: break-all;
}
</style>
