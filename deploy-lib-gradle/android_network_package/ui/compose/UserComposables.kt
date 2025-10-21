package com.vibe.network.ui.compose

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Card
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vibe.network.data.model.User
import com.vibe.network.ui.viewmodel.UserViewModel

/**
 * Composable for displaying a single user
 */
@Composable
fun UserCard(
    user: User,
    modifier: Modifier = Modifier,
    onDelete: () -> Unit = {},
    onEdit: () -> Unit = {}
) {
    Card(
        modifier = modifier
            .fillMaxWidth()
            .padding(8.dp)
    ) {
        Column(
            modifier = Modifier.padding(16.dp)
        ) {
            Text(
                text = user.name,
                fontSize = 18.sp,
                modifier = Modifier.padding(bottom = 4.dp)
            )
            Text(
                text = user.email,
                fontSize = 14.sp,
                modifier = Modifier.padding(bottom = 4.dp)
            )
            if (!user.createdAt.isNullOrEmpty()) {
                Text(
                    text = "Created: ${user.createdAt}",
                    fontSize = 12.sp
                )
            }
            Row(modifier = Modifier.padding(top = 12.dp)) {
                androidx.compose.material3.Button(
                    onClick = onEdit,
                    modifier = Modifier.padding(end = 8.dp)
                ) {
                    Text("Edit")
                }
                androidx.compose.material3.Button(
                    onClick = onDelete,
                    modifier = Modifier.padding(start = 8.dp)
                ) {
                    Text("Delete")
                }
            }
        }
    }
}

/**
 * Composable for displaying a list of users
 */
@Composable
fun UserList(
    users: List<User>,
    modifier: Modifier = Modifier,
    onUserDelete: (String) -> Unit = {},
    onUserEdit: (User) -> Unit = {}
) {
    LazyColumn(modifier = modifier) {
        items(users, key = { it.id }) { user ->
            UserCard(
                user = user,
                onDelete = { onUserDelete(user.id) },
                onEdit = { onUserEdit(user) }
            )
        }
    }
}

/**
 * Screen for displaying user list with ViewModel integration
 */
@Composable
fun UserListScreen(
    viewModel: UserViewModel,
    modifier: Modifier = Modifier,
    onUserClick: (User) -> Unit = {}
) {
    val usersState = viewModel.usersListState.collectAsState()
    
    LaunchedEffect(Unit) {
        viewModel.listUsers()
    }
    
    NetworkStateList(
        state = usersState.value,
        modifier = modifier,
        listContent = { users ->
            UserList(
                users = users,
                onUserEdit = onUserClick,
                onUserDelete = { userId ->
                    viewModel.deleteUser(userId)
                }
            )
        }
    )
}

/**
 * Screen for displaying a single user with ViewModel integration
 */
@Composable
fun UserDetailScreen(
    viewModel: UserViewModel,
    userId: String,
    modifier: Modifier = Modifier
) {
    val userState = viewModel.userState.collectAsState()
    
    LaunchedEffect(userId) {
        viewModel.getUser(userId)
    }
    
    NetworkStateItem(
        state = userState.value,
        modifier = modifier,
        itemContent = { user ->
            UserCard(
                user = user,
                onDelete = {
                    viewModel.deleteUser(user.id)
                }
            )
        }
    )
}
