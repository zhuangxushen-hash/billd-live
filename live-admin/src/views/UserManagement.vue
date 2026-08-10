<template>
  <div class="user-management">
    <el-card>
      <template #header>
        <div class="header">
          <span class="title">用户管理</span>
          <el-button type="primary" @click="showCreateDialog = true">
            <el-icon><Plus /></el-icon>
            添加用户
          </el-button>
        </div>
      </template>
      
      <el-table :data="users" style="width: 100%">
        <el-table-column prop="id" label="ID" width="60" />
        <el-table-column prop="username" label="用户名" width="150" />
        <el-table-column prop="nickname" label="昵称" width="150" />
        <el-table-column prop="role" label="角色" width="100">
          <template #default="{ row }">
            <el-tag :type="row.role === 'admin' ? 'danger' : 'info'" size="small">
              {{ row.role === 'admin' ? '管理员' : '普通用户' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="150">
          <template #default="{ row }">
            <el-button type="primary" size="small" @click="editUser(row)">编辑</el-button>
            <el-button 
              type="danger" 
              size="small" 
              @click="deleteUser(row)"
              :disabled="row.id === 1"
            >
              删除
            </el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <el-dialog v-model="showCreateDialog" title="添加用户" width="450px">
      <el-form :model="createForm" label-width="80px">
        <el-form-item label="用户名">
          <el-input v-model="createForm.username" placeholder="请输入用户名" />
        </el-form-item>
        <el-form-item label="密码">
          <el-input v-model="createForm.password" type="password" placeholder="请输入密码" />
        </el-form-item>
        <el-form-item label="昵称">
          <el-input v-model="createForm.nickname" placeholder="请输入昵称" />
        </el-form-item>
        <el-form-item label="角色">
          <el-select v-model="createForm.role">
            <el-option label="管理员" value="admin" />
            <el-option label="普通用户" value="user" />
          </el-select>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showCreateDialog = false">取消</el-button>
        <el-button type="primary" @click="createUser">创建</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'

const users = ref([])
const showCreateDialog = ref(false)
const createForm = ref({
  username: '',
  password: '',
  nickname: '',
  role: 'user'
})

async function fetchUsers() {
  try {
    const res = await fetch('/api/users')
    const data = await res.json()
    if (data.success) {
      users.value = data.data
    }
  } catch (e) {
    console.error('获取用户列表失败:', e)
  }
}

async function createUser() {
  if (!createForm.value.username || !createForm.value.password) {
    ElMessage.warning('请填写完整信息')
    return
  }
  
  try {
    const res = await fetch('/api/users', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(createForm.value)
    })
    const data = await res.json()
    if (data.success) {
      ElMessage.success('创建成功')
      showCreateDialog.value = false
      createForm.value = { username: '', password: '', nickname: '', role: 'user' }
      fetchUsers()
    }
  } catch (e) {
    ElMessage.error('创建失败')
  }
}

function editUser(user) {
  ElMessage.info(`编辑用户 ${user.username}`)
}

async function deleteUser(user) {
  try {
    await ElMessageBox.confirm(
      `确定要删除用户 "${user.username}" 吗？`,
      '确认删除',
      { type: 'warning' }
    )
    ElMessage.success('删除成功')
  } catch (e) {
    // 用户取消
  }
}

onMounted(() => {
  fetchUsers()
})
</script>

<style scoped>
.user-management { }
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
</style>
