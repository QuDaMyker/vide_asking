package com.vibe.network.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.vibe.network.Result
import com.vibe.network.data.model.User
import com.vibe.network.data.repository.UserRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * ViewModel for managing user-related UI state
 */
class UserViewModel(
    private val repository: UserRepository
) : ViewModel() {
    
    private val _userState = MutableStateFlow<Result<User>>(Result.Loading)
    val userState: StateFlow<Result<User>> = _userState.asStateFlow()
    
    private val _usersListState = MutableStateFlow<Result<List<User>>>(Result.Loading)
    val usersListState: StateFlow<Result<List<User>>> = _usersListState.asStateFlow()
    
    private val _currentPage = MutableStateFlow(1)
    val currentPage: StateFlow<Int> = _currentPage.asStateFlow()
    
    fun getUser(userId: String) {
        viewModelScope.launch {
            _userState.value = Result.Loading
            _userState.value = repository.getUser(userId)
        }
    }
    
    fun listUsers(page: Int = 1, limit: Int = 20) {
        viewModelScope.launch {
            _usersListState.value = Result.Loading
            _currentPage.value = page
            _usersListState.value = repository.listUsers(page, limit)
        }
    }
    
    fun createUser(name: String, email: String, password: String) {
        viewModelScope.launch {
            _userState.value = Result.Loading
            _userState.value = repository.createUser(name, email, password)
        }
    }
    
    fun updateUser(
        userId: String,
        name: String? = null,
        email: String? = null,
        avatar: String? = null
    ) {
        viewModelScope.launch {
            _userState.value = Result.Loading
            _userState.value = repository.updateUser(userId, name, email, avatar)
        }
    }
    
    fun deleteUser(userId: String) {
        viewModelScope.launch {
            repository.deleteUser(userId)
            listUsers()
        }
    }
    
    fun resetState() {
        _userState.value = Result.Loading
        _usersListState.value = Result.Loading
    }
}
