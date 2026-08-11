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
        <el-table-column label="操作" width="280">
          <template #default="{ row }">
            <el-button type="primary" size="small" @click="editUser(row)">编辑</el-button>
            <el-button 
              type="warning" 
              size="small" 
              @click="openResetPasswordDialog(row)"
            >
              重置密码
            </el-button>
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

    <!-- 重置用户密码对话框 -->
    <el-dialog v-model="showResetPasswordDialog" title="重置用户密码" width="450px">
      <el-form :model="resetPasswordForm" label-width="100px">
        <el-form-item label="用户名">
          <el-input v-model="resetPasswordForm.username" disabled />
        </el-form-item>
        <el-form-item label="新密码">
          <el-input v-model="resetPasswordForm.newPassword" type="password" placeholder="请输入新密码" />
        </el-form-item>
        <el-form-item label="确认密码">
          <el-input v-model="resetPasswordForm.confirmPassword" type="password" placeholder="请再次输入新密码" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showResetPasswordDialog = false">取消</el-button>
        <el-button type="primary" @click="resetUserPassword">确认重置</el-button>
      </template>
    </el-dialog>

    <!-- 修改自己密码对话框 -->
    <el-dialog v-model="showChangePasswordDialog" title="修改密码" width="450px">
      <el-form :model="changePasswordForm" label-width="100px">
        <el-form-item label="当前密码">
          <el-input v-model="changePasswordForm.oldPassword" type="password" placeholder="请输入当前密码" />
        </el-form-item>
        <el-form-item label="新密码">
          <el-input v-model="changePasswordForm.newPassword" type="password" placeholder="请输入新密码" />
        </el-form-item>
        <el-form-item label="确认密码">
          <el-input v-model="changePasswordForm.confirmPassword" type="password" placeholder="请再次输入新密码" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showChangePasswordDialog = false">取消</el-button>
        <el-button type="primary" @click="changeMyPassword">确认修改</el-button>
      </template>
    </el-dialog>

    <!-- 编辑用户对话框 -->
    <el-dialog v-model="showEditDialog" title="编辑用户" width="450px">
      <el-form :model="editForm" label-width="80px">
        <el-form-item label="用户名">
          <el-input v-model="editForm.username" disabled />
        </el-form-item>
        <el-form-item label="昵称">
          <el-input v-model="editForm.nickname" placeholder="请输入昵称" />
        </el-form-item>
        <el-form-item label="角色">
          <el-select v-model="editForm.role">
            <el-option label="管理员" value="admin" />
            <el-option label="普通用户" value="user" />
          </el-select>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showEditDialog = false">取消</el-button>
        <el-button type="primary" @click="saveEditUser">保存</el-button>
      </template>
    </el-dialog>

    <!-- 修改自己密码按钮 -->
    <el-card style="margin-top: 16px;">
      <div class="self-password-section">
        <span>账号安全</span>
        <el-button type="primary" @click="showChangePasswordDialog = true">
          修改我的密码
        </el-button>
      </div>
    </el-card>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'

const users = ref([])
const showCreateDialog = ref(false)
const showResetPasswordDialog = ref(false)
const showChangePasswordDialog = ref(false)
const currentUser = ref(null)

const createForm = ref({
  username: '',
  password: '',
  nickname: '',
  role: 'user'
})

const resetPasswordForm = ref({
  userId: null,
  username: '',
  newPassword: '',
  confirmPassword: ''
})

const changePasswordForm = ref({
  oldPassword: '',
  newPassword: '',
  confirmPassword: ''
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

// 获取当前登录用户信息
async function fetchCurrentUser() {
  try {
    const userStr = localStorage.getItem('user')
    if (userStr) {
      currentUser.value = JSON.parse(userStr)
    }
  } catch (e) {
    console.error('获取当前用户信息失败:', e)
  }
}

// 添加用户
async function createUser() {
  if (!createForm.value.username || !createForm.value.password) {
    ElMessage.warning('请填写完整信息')
    return
  }
  
  try {
    const res = await fetch('/api/users/create', {
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
    } else {
      ElMessage.error(data.message || '创建失败')
    }
  } catch (e) {
    ElMessage.error('创建失败')
  }
}

// 编辑用户 - 打开编辑对话框
const showEditDialog = ref(false)
const editForm = ref({
  id: null,
  username: '',
  nickname: '',
  role: 'user'
})

function editUser(user) {
  editForm.value = {
    id: user.id,
    username: user.username,
    nickname: user.nickname,
    role: user.role
  }
  showEditDialog.value = true
}

// 保存编辑
async function saveEditUser() {
  try {
    const res = await fetch(`/api/users/${editForm.value.id}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        nickname: editForm.value.nickname,
        role: editForm.value.role
      })
    })
    const data = await res.json()
    if (data.success) {
      ElMessage.success('更新成功')
      showEditDialog.value = false
      fetchUsers()
    } else {
      ElMessage.error(data.message || '更新失败')
    }
  } catch (e) {
    ElMessage.error('更新失败')
  }
}

// 删除用户
async function deleteUser(user) {
  if (user.id === 1) {
    ElMessage.warning('不能删除管理员账户')
    return
  }
  try {
    await ElMessageBox.confirm(
      `确定要删除用户 "${user.username}" 吗？`,
      '确认删除',
      { type: 'warning' }
    )
    const res = await fetch(`/api/users/${user.id}`, { method: 'DELETE' })
    const data = await res.json()
    if (data.success) {
      ElMessage.success('删除成功')
      fetchUsers()
    } else {
      ElMessage.error(data.message || '删除失败')
    }
  } catch (e) {
    // 用户取消
  }
}

// 打开重置密码对话框
function openResetPasswordDialog(user) {
  resetPasswordForm.value = {
    userId: user.id,
    username: user.username,
    newPassword: '',
    confirmPassword: ''
  }
  showResetPasswordDialog.value = true
}

// 重置用户密码
async function resetUserPassword() {
  const { newPassword, confirmPassword } = resetPasswordForm.value
  
  if (!newPassword || !confirmPassword) {
    ElMessage.warning('请填写完整信息')
    return
  }
  
  if (newPassword !== confirmPassword) {
    ElMessage.error('两次输入的密码不一致')
    return
  }
  
  if (newPassword.length < 6) {
    ElMessage.error('密码长度至少6位')
    return
  }
  
  try {
    const res = await fetch(`/api/users/${resetPasswordForm.value.userId}/reset-password`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ newPassword })
    })
    const data = await res.json()
    if (data.success) {
      ElMessage.success('密码重置成功')
      showResetPasswordDialog.value = false
      resetPasswordForm.value = { userId: null, username: '', newPassword: '', confirmPassword: '' }
    } else {
      ElMessage.error(data.message || '重置失败')
    }
  } catch (e) {
    ElMessage.error('重置失败')
  }
}

// 修改自己的密码
async function changeMyPassword() {
  const { oldPassword, newPassword, confirmPassword } = changePasswordForm.value
  
  if (!oldPassword || !newPassword || !confirmPassword) {
    ElMessage.warning('请填写完整信息')
    return
  }
  
  if (newPassword !== confirmPassword) {
    ElMessage.error('两次输入的密码不一致')
    return
  }
  
  if (newPassword.length < 6) {
    ElMessage.error('新密码长度至少6位')
    return
  }
  
  if (oldPassword === newPassword) {
    ElMessage.error('新密码不能与旧密码相同')
    return
  }
  
  try {
    const res = await fetch('/api/users/change-password', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ 
        userId: currentUser.value?.id,
        oldPassword, 
        newPassword 
      })
    })
    const data = await res.json()
    if (data.success) {
      ElMessage.success('密码修改成功')
      showChangePasswordDialog.value = false
      changePasswordForm.value = { oldPassword: '', newPassword: '', confirmPassword: '' }
    } else {
      ElMessage.error(data.message || '修改失败')
    }
  } catch (e) {
    ElMessage.error('修改失败')
  }
}

onMounted(() => {
  fetchUsers()
  fetchCurrentUser()
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
.self-password-section {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: 14px;
  color: #606266;
}
</style>
