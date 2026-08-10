<template>
  <div class="popup-config">
    <!-- 弹窗图片管理 -->
    <el-card class="popup-list-card">
      <template #header>
        <div class="card-header">
          <span>弹窗图片库</span>
          <el-upload
            :show-file-list="false"
            :before-upload="handleUpload"
            :http-request="uploadPopup"
            accept="image/*"
          >
            <el-button type="primary">
              <el-icon><Upload /></el-icon>
              上传图片
            </el-button>
          </el-upload>
        </div>
      </template>
      
      <div v-if="popups.length === 0" class="empty-state">
        <el-empty description="暂无弹窗图片，点击上传按钮添加" />
      </div>
      
      <el-row v-else :gutter="16">
        <el-col 
          v-for="popup in popups" 
          :key="popup.id" 
          :xs="24" 
          :sm="12" 
          :md="8" 
          :lg="6"
        >
          <div class="popup-item">
            <div class="popup-preview">
              <img :src="popup.url" :alt="popup.name" />
              <div class="popup-actions">
                <el-button 
                  size="small" 
                  @click="previewImage(popup)"
                >
                  <el-icon><View /></el-icon>
                </el-button>
                <el-button 
                  size="small" 
                  type="danger" 
                  @click="deletePopup(popup.id)"
                >
                  <el-icon><Delete /></el-icon>
                </el-button>
              </div>
            </div>
            <div class="popup-info">
              <div class="popup-name" :title="popup.name">{{ popup.name }}</div>
              <div class="popup-meta">{{ formatSize(popup.size) }}</div>
            </div>
          </div>
        </el-col>
      </el-row>
    </el-card>

    <!-- 直播间弹窗配置 -->
    <el-card class="room-popup-card" style="margin-top: 20px;">
      <template #header>
        <div class="card-header">
          <span>直播间弹窗配置</span>
        </div>
      </template>
      
      <el-form :model="form" label-width="120px">
        <el-form-item label="选择直播间">
          <el-select 
            v-model="form.roomId" 
            placeholder="请选择直播间"
            @change="handleRoomChange"
          >
            <el-option 
              v-for="room in rooms" 
              :key="room.id" 
              :label="room.title" 
              :value="room.id"
            />
          </el-select>
        </el-form-item>
        
        <el-form-item v-if="form.roomId" label="启用弹窗">
          <el-switch 
            v-model="form.enabled" 
            active-text="启用" 
            inactive-text="关闭"
          />
        </el-form-item>
        
        <el-form-item v-if="form.roomId && form.enabled" label="选择弹窗图片">
          <el-select 
            v-model="form.popupId" 
            placeholder="请选择弹窗图片"
            filterable
          >
            <el-option 
              v-for="popup in popups" 
              :key="popup.id" 
              :label="popup.name" 
              :value="popup.id"
            />
          </el-select>
        </el-form-item>
        
        <el-form-item v-if="form.roomId && form.enabled" label="预览效果">
          <div v-if="selectedPopup" class="popup-preview-box">
            <img :src="selectedPopup.url" :alt="selectedPopup.name" />
          </div>
          <div v-else class="popup-preview-placeholder">
            选择图片后在此预览
          </div>
        </el-form-item>
        
        <el-form-item v-if="form.roomId && form.enabled" label="延迟显示">
          <el-input-number 
            v-model="form.delayTime" 
            :min="0" 
            :max="60"
            suffix="秒"
          />
          <div class="form-tip">进入直播间后，延迟多久显示弹窗</div>
        </el-form-item>
        
        <el-form-item v-if="form.roomId && form.enabled" label="显示时长">
          <el-input-number 
            v-model="form.displayDuration" 
            :min="1" 
            :max="60"
            suffix="秒"
          />
          <div class="form-tip">弹窗显示后，持续多少秒自动关闭</div>
        </el-form-item>
        
        <el-form-item v-if="form.roomId" label="当前状态">
          <div class="current-config">
            <template v-if="currentConfig.enabled && currentConfig.image">
              <el-tag type="success">已启用</el-tag>
              <span class="config-detail">
                {{ currentConfig.image.name }} · 
                延迟 {{ currentConfig.delayTime }} 秒 · 
                显示 {{ currentConfig.displayDuration }} 秒
              </span>
            </template>
            <template v-else-if="currentConfig.enabled">
              <el-tag type="warning">已启用但未选择图片</el-tag>
            </template>
            <template v-else>
              <el-tag>未启用</el-tag>
            </template>
          </div>
        </el-form-item>
        
        <el-form-item v-if="form.roomId">
          <el-button type="primary" @click="saveConfig">
            保存配置
          </el-button>
          <el-button @click="resetForm">重置</el-button>
        </el-form-item>
      </el-form>
    </el-card>

    <!-- 实时弹窗控制 -->
    <el-card v-if="form.roomId && form.enabled" class="realtime-popup-card" style="margin-top: 20px;">
      <template #header>
        <div class="card-header">
          <span>实时弹窗控制</span>
          <el-tag type="success">直播中实时生效</el-tag>
        </div>
      </template>
      
      <el-form :model="realtimeForm" label-width="120px">
        <el-form-item label="弹窗图片">
          <el-select 
            v-model="realtimeForm.popupId" 
            placeholder="选择弹窗图片"
            filterable
          >
            <el-option 
              v-for="popup in popups" 
              :key="popup.id" 
              :label="popup.name" 
              :value="popup.id"
            />
          </el-select>
          <div class="form-tip">不选择则使用上方配置的弹窗图片</div>
        </el-form-item>
        
        <el-form-item label="显示时长">
          <el-input-number 
            v-model="realtimeForm.displayDuration" 
            :min="1" 
            :max="60"
            suffix="秒"
          />
        </el-form-item>
        
        <el-form-item label="立即弹出">
          <el-button 
            type="danger" 
            @click="triggerPopup('immediate')"
            :disabled="!realtimeForm.popupId && !form.popupId"
          >
            <el-icon><Promotion /></el-icon>
            立即推送给观众
          </el-button>
          <div class="form-tip">点击后弹窗会立即在所有在线观众的客户端弹出</div>
        </el-form-item>
        
        <el-form-item label="定时弹出">
          <div class="schedule-controls">
            <el-radio-group v-model="realtimeForm.scheduleType">
              <el-radio value="delay">延迟秒数</el-radio>
              <el-radio value="time">指定时间</el-radio>
            </el-radio-group>
            
            <div v-if="realtimeForm.scheduleType === 'delay'" class="delay-input">
              <el-input-number 
                v-model="realtimeForm.delaySeconds" 
                :min="1" 
                :max="3600"
                suffix="秒"
              />
              <el-button 
                type="warning"
                @click="triggerPopup('delay')"
                :disabled="!realtimeForm.popupId && !form.popupId"
              >
                延迟弹出
              </el-button>
            </div>
            
            <div v-if="realtimeForm.scheduleType === 'time'" class="time-input">
              <el-date-picker 
                v-model="realtimeForm.scheduleTime" 
                type="datetime" 
                placeholder="选择弹出时间"
                format="YYYY-MM-DD HH:mm:ss"
                value-format="YYYY-MM-DDTHH:mm:ss"
              />
              <el-button 
                type="warning"
                @click="triggerPopup('time')"
                :disabled="!realtimeForm.scheduleTime || (!realtimeForm.popupId && !form.popupId)"
              >
                定时弹出
              </el-button>
            </div>
          </div>
        </el-form-item>
      </el-form>
    </el-card>

    <!-- 定时任务列表 -->
    <el-card v-if="scheduledTasks.length > 0" class="scheduled-tasks-card" style="margin-top: 20px;">
      <template #header>
        <div class="card-header">
          <span>等待执行的定时任务</span>
          <el-button size="small" @click="loadScheduledTasks">刷新</el-button>
        </div>
      </template>
      
      <el-table :data="scheduledTasks" style="width: 100%">
        <el-table-column prop="popupImage.name" label="弹窗图片" />
        <el-table-column prop="scheduleTime" label="执行时间">
          <template #default="scope">
            {{ formatDate(scope.row.scheduleTime) }}
          </template>
        </el-table-column>
        <el-table-column prop="displayDuration" label="显示时长">
          <template #default="scope">
            {{ scope.row.displayDuration }} 秒
          </template>
        </el-table-column>
        <el-table-column label="操作" width="120">
          <template #default="scope">
            <el-button 
              size="small" 
              type="danger" 
              @click="cancelScheduledTask(scope.row.id)"
            >
              取消
            </el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <!-- 图片预览对话框 -->
    <el-dialog v-model="previewVisible" title="图片预览" width="500px">
      <div class="preview-dialog">
        <img v-if="previewPopup" :src="previewPopup.url" :alt="previewPopup.name" />
        <div class="preview-info" v-if="previewPopup">
          <p><strong>名称：</strong>{{ previewPopup.name }}</p>
          <p><strong>大小：</strong>{{ formatSize(previewPopup.size) }}</p>
          <p><strong>上传时间：</strong>{{ formatDate(previewPopup.createdAt) }}</p>
        </div>
      </div>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Upload, View, Delete, Promotion } from '@element-plus/icons-vue'

const popups = ref([])
const rooms = ref([])
const form = ref({
  roomId: null,
  popupId: null,
  enabled: false,
  delayTime: 3,
  displayDuration: 5
})
const currentConfig = ref({
  enabled: false,
  popupId: null,
  delayTime: 3,
  displayDuration: 5,
  image: null
})
const previewVisible = ref(false)
const previewPopup = ref(null)

// 实时弹窗控制相关
const realtimeForm = ref({
  popupId: null,
  displayDuration: 5,
  scheduleType: 'delay',
  delaySeconds: 10,
  scheduleTime: null
})
const scheduledTasks = ref([])

const selectedPopup = computed(() => {
  if (!form.value.popupId) return null
  return popups.value.find(p => p.id === form.value.popupId)
})

onMounted(() => {
  loadPopups()
  loadRooms()
  loadScheduledTasks()
})

async function loadPopups() {
  try {
    const res = await fetch('/api/popups')
    const data = await res.json()
    if (data.success) {
      popups.value = data.data
    }
  } catch (e) {
    console.error('加载弹窗图片失败:', e)
  }
}

async function loadRooms() {
  try {
    const res = await fetch('/api/rooms')
    const data = await res.json()
    if (data.success) {
      rooms.value = data.data
    }
  } catch (e) {
    console.error('加载直播间列表失败:', e)
  }
}

async function uploadPopup(options) {
  const formData = new FormData()
  formData.append('image', options.file)
  formData.append('name', options.file.name)
  
  try {
    const res = await fetch('/api/popups/upload', {
      method: 'POST',
      body: formData
    })
    const data = await res.json()
    if (data.success) {
      ElMessage.success('上传成功')
      loadPopups()
    } else {
      ElMessage.error(data.message || '上传失败')
    }
  } catch (e) {
    ElMessage.error('上传失败: ' + e.message)
  }
}

function handleUpload(file) {
  const allowedTypes = ['image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/bmp']
  if (!allowedTypes.includes(file.type)) {
    ElMessage.error('只支持 JPG、PNG、GIF、WEBP、BMP 格式')
    return false
  }
  if (file.size > 10 * 1024 * 1024) {
    ElMessage.error('图片大小不能超过 10MB')
    return false
  }
  return true
}

function previewImage(popup) {
  previewPopup.value = popup
  previewVisible.value = true
}

async function deletePopup(id) {
  try {
    await ElMessageBox.confirm('确定要删除这张弹窗图片吗？', '确认删除', {
      type: 'warning'
    })
    
    const res = await fetch(`/api/popups/${id}`, {
      method: 'DELETE'
    })
    const data = await res.json()
    if (data.success) {
      ElMessage.success('删除成功')
      loadPopups()
      if (form.value.popupId === id) {
        form.value.popupId = null
      }
    } else {
      ElMessage.error(data.message || '删除失败')
    }
  } catch (e) {
    if (e !== 'cancel') {
      console.error('删除失败:', e)
    }
  }
}

async function handleRoomChange(roomId) {
  if (!roomId) {
    resetForm()
    return
  }
  
  try {
    const res = await fetch(`/api/rooms/${roomId}/popup`)
    const data = await res.json()
    if (data.success) {
      currentConfig.value = data.data
      form.value.enabled = data.data.enabled
      form.value.popupId = data.data.popupId
      form.value.delayTime = data.data.delayTime
      form.value.displayDuration = data.data.displayDuration
    }
  } catch (e) {
    console.error('加载配置失败:', e)
  }
}

async function saveConfig() {
  if (!form.value.roomId) {
    ElMessage.warning('请先选择直播间')
    return
  }
  
  try {
    const res = await fetch(`/api/rooms/${form.value.roomId}/popup`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        popupId: form.value.popupId,
        enabled: form.value.enabled,
        delayTime: form.value.delayTime,
        displayDuration: form.value.displayDuration
      })
    })
    const data = await res.json()
    if (data.success) {
      ElMessage.success('保存成功')
      currentConfig.value = {
        ...data.data,
        image: popups.value.find(p => p.id === data.data.popupId)
      }
    } else {
      ElMessage.error(data.message || '保存失败')
    }
  } catch (e) {
    ElMessage.error('保存失败: ' + e.message)
  }
}

function resetForm() {
  form.value = {
    roomId: null,
    popupId: null,
    enabled: false,
    delayTime: 3,
    displayDuration: 5
  }
  currentConfig.value = {
    enabled: false,
    popupId: null,
    delayTime: 3,
    displayDuration: 5,
    image: null
  }
}

function formatSize(bytes) {
  if (bytes < 1024) return bytes + ' B'
  if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB'
  return (bytes / 1024 / 1024).toFixed(1) + ' MB'
}

function formatDate(dateStr) {
  if (!dateStr) return ''
  return new Date(dateStr).toLocaleString('zh-CN')
}

/**
 * 触发弹窗（立即或定时）
 */
async function triggerPopup(type) {
  const roomId = form.value.roomId
  if (!roomId) {
    ElMessage.warning('请先选择直播间')
    return
  }
  
  // 确定弹窗图片ID
  const popupId = realtimeForm.value.popupId || form.value.popupId
  if (!popupId) {
    ElMessage.warning('请选择弹窗图片')
    return
  }
  
  try {
    let url = ''
    let body = {
      popupId: popupId,
      displayDuration: realtimeForm.value.displayDuration
    }
    
    if (type === 'immediate') {
      url = `/api/rooms/${roomId}/popup/trigger`
    } else if (type === 'delay') {
      url = `/api/rooms/${roomId}/popup/schedule`
      body.delaySeconds = realtimeForm.value.delaySeconds
    } else if (type === 'time') {
      url = `/api/rooms/${roomId}/popup/schedule`
      body.scheduleTime = realtimeForm.value.scheduleTime
    }
    
    const res = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(body)
    })
    const data = await res.json()
    
    if (data.success) {
      ElMessage.success(data.message || '操作成功')
      if (type !== 'immediate') {
        loadScheduledTasks()
      }
    } else {
      ElMessage.error(data.message || '操作失败')
    }
  } catch (e) {
    ElMessage.error('操作失败: ' + e.message)
  }
}

/**
 * 加载定时任务列表
 */
async function loadScheduledTasks() {
  try {
    const res = await fetch('/api/scheduled-popups')
    const data = await res.json()
    if (data.success) {
      scheduledTasks.value = data.data
    }
  } catch (e) {
    console.error('加载定时任务失败:', e)
  }
}

/**
 * 取消定时任务
 */
async function cancelScheduledTask(taskId) {
  try {
    await ElMessageBox.confirm('确定要取消这个定时任务吗？', '确认取消', {
      type: 'warning'
    })
    
    const res = await fetch(`/api/scheduled-popups/${taskId}`, {
      method: 'DELETE'
    })
    const data = await res.json()
    if (data.success) {
      ElMessage.success('取消成功')
      loadScheduledTasks()
    } else {
      ElMessage.error(data.message || '取消失败')
    }
  } catch (e) {
    if (e !== 'cancel') {
      console.error('取消任务失败:', e)
    }
  }
}
</script>

<style scoped>
.popup-config {
  max-width: 1200px;
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.popup-list-card {
  background: white;
}

.popup-item {
  margin-bottom: 16px;
  border-radius: 8px;
  overflow: hidden;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  transition: transform 0.2s, box-shadow 0.2s;
}

.popup-item:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.15);
}

.popup-preview {
  position: relative;
  width: 100%;
  padding-top: 75%;
  background: #f5f5f5;
  overflow: hidden;
}

.popup-preview img {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.popup-actions {
  position: absolute;
  top: 8px;
  right: 8px;
  display: flex;
  gap: 4px;
  opacity: 0;
  transition: opacity 0.2s;
}

.popup-item:hover .popup-actions {
  opacity: 1;
}

.popup-actions .el-button {
  backdrop-filter: blur(4px);
  background: rgba(255, 255, 255, 0.9);
}

.popup-info {
  padding: 12px;
  background: white;
}

.popup-name {
  font-size: 14px;
  font-weight: 500;
  color: #333;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.popup-meta {
  font-size: 12px;
  color: #999;
  margin-top: 4px;
}

.empty-state {
  padding: 40px 0;
}

.popup-preview-box {
  width: 200px;
  height: 120px;
  border: 2px dashed #d9d9d9;
  border-radius: 8px;
  overflow: hidden;
  display: flex;
  align-items: center;
  justify-content: center;
}

.popup-preview-box img {
  width: 100%;
  height: 100%;
  object-fit: contain;
}

.popup-preview-placeholder {
  width: 200px;
  height: 120px;
  border: 2px dashed #d9d9d9;
  border-radius: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #999;
  font-size: 12px;
}

.form-tip {
  font-size: 12px;
  color: #999;
  margin-top: 4px;
}

.current-config {
  display: flex;
  align-items: center;
  gap: 8px;
}

.config-detail {
  font-size: 13px;
  color: #666;
}

.preview-dialog {
  text-align: center;
}

.preview-dialog img {
  max-width: 100%;
  max-height: 400px;
  border-radius: 8px;
}

.preview-info {
  margin-top: 16px;
  text-align: left;
  padding: 16px;
  background: #f5f5f5;
  border-radius: 8px;
}

.preview-info p {
  margin: 4px 0;
  font-size: 14px;
}

.realtime-popup-card {
  border-left: 4px solid #f56c6c;
}

.realtime-popup-card .el-card__header {
  background: linear-gradient(135deg, #fff5f5 0%, #fff 100%);
}

.schedule-controls {
  display: flex;
  flex-direction: column;
  gap: 12px;
  width: 100%;
}

.delay-input,
.time-input {
  display: flex;
  gap: 12px;
  align-items: center;
}

.scheduled-tasks-card {
  border-left: 4px solid #e6a23c;
}

.scheduled-tasks-card .el-card__header {
  background: linear-gradient(135deg, #fdf6ec 0%, #fff 100%);
}
</style>
