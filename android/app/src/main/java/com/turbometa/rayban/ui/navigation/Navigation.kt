package com.turbometa.rayban.ui.navigation

import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Message
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.meta.wearable.dat.core.types.Permission
import com.meta.wearable.dat.core.types.PermissionStatus
import com.turbometa.rayban.R
import com.turbometa.rayban.ui.screens.*
import com.turbometa.rayban.ui.theme.Primary
import com.turbometa.rayban.viewmodels.WearablesViewModel

sealed class Screen(val route: String) {
    object Home : Screen("home")
    object LiveAI : Screen("live_ai")
    object LeanEat : Screen("lean_eat")
    object Vision : Screen("vision")
    object QuickVision : Screen("quick_vision")
    object Settings : Screen("settings")
    object Records : Screen("records")
    object Gallery : Screen("gallery")
    object LiveStream : Screen("live_stream")
    object RTMPStream : Screen("rtmp_stream")
}

sealed class BottomNavItem(
    val route: String,
    val icon: ImageVector,
    val labelResId: Int
) {
    object Home : BottomNavItem("home", Icons.Default.Home, R.string.home)
    object Records : BottomNavItem("records", Icons.AutoMirrored.Filled.Message, R.string.records)
    object Gallery : BottomNavItem("gallery", Icons.Default.Photo, R.string.gallery)
    object Settings : BottomNavItem("settings", Icons.Default.Person, R.string.settings)
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TurboMetaNavigation(
    wearablesViewModel: WearablesViewModel,
    onRequestWearablesPermission: suspend (Permission) -> PermissionStatus
) {
    val navController = rememberNavController()

    val bottomNavItems = listOf(
        BottomNavItem.Home,
        BottomNavItem.Records,
        BottomNavItem.Gallery,
        BottomNavItem.Settings
    )

    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = navBackStackEntry?.destination?.route

    // Determine if we should show bottom nav
    val showBottomNav = currentRoute in bottomNavItems.map { it.route }

    Scaffold(
        bottomBar = {
            if (showBottomNav) {
                NavigationBar {
                    bottomNavItems.forEach { item ->
                        NavigationBarItem(
                            icon = {
                                Icon(
                                    imageVector = item.icon,
                                    contentDescription = stringResource(item.labelResId)
                                )
                            },
                            label = { Text(stringResource(item.labelResId)) },
                            selected = currentRoute == item.route,
                            onClick = {
                                navController.navigate(item.route) {
                                    popUpTo(navController.graph.findStartDestination().id) {
                                        saveState = true
                                    }
                                    launchSingleTop = true
                                    restoreState = true
                                }
                            },
                            colors = NavigationBarItemDefaults.colors(
                                selectedIconColor = Primary,
                                selectedTextColor = Primary,
                                indicatorColor = Primary.copy(alpha = 0.1f)
                            )
                        )
                    }
                }
            }
        }
    ) { paddingValues ->
        NavHost(
            navController = navController,
            startDestination = Screen.Home.route,
            modifier = Modifier.padding(paddingValues)
        ) {
            composable(Screen.Home.route) {
                HomeScreen(
                    wearablesViewModel = wearablesViewModel,
                    onRequestWearablesPermission = onRequestWearablesPermission,
                    onNavigateToLiveAI = {
                        navController.navigate(Screen.LiveAI.route)
                    },
                    onNavigateToLeanEat = {
                        navController.navigate(Screen.LeanEat.route)
                    },
                    onNavigateToVision = {
                        navController.navigate(Screen.QuickVision.route)
                    },
                    onNavigateToSettings = {
                        navController.navigate(Screen.Settings.route)
                    },
                    onNavigateToLiveStream = {
                        navController.navigate(Screen.LiveStream.route)
                    },
                    onNavigateToRTMPStream = {
                        navController.navigate(Screen.RTMPStream.route)
                    }
                )
            }

            composable(Screen.LiveAI.route) {
                LiveAIScreen(
                    wearablesViewModel = wearablesViewModel,
                    onRequestWearablesPermission = onRequestWearablesPermission,
                    onBackClick = {
                        navController.popBackStack()
                    }
                )
            }

            composable(Screen.LeanEat.route) {
                val currentFrame by wearablesViewModel.currentFrame.collectAsState()
                LeanEatScreen(
                    currentFrame = currentFrame,
                    onBackClick = {
                        navController.popBackStack()
                    },
                    onTakePhoto = {
                        wearablesViewModel.takePhoto()
                    }
                )
            }

            composable(Screen.Vision.route) {
                val currentFrame by wearablesViewModel.currentFrame.collectAsState()
                VisionScreen(
                    currentFrame = currentFrame,
                    onBackClick = {
                        navController.popBackStack()
                    },
                    onTakePhoto = {
                        wearablesViewModel.takePhoto()
                    }
                )
            }

            composable(Screen.QuickVision.route) {
                QuickVisionScreen(
                    wearablesViewModel = wearablesViewModel,
                    onBackClick = {
                        navController.popBackStack()
                    }
                )
            }

            composable(Screen.Settings.route) {
                SettingsScreen(
                    onBackClick = {
                        navController.popBackStack()
                    },
                    onNavigateToRecords = {
                        navController.navigate(Screen.Records.route)
                    }
                )
            }

            composable(Screen.Records.route) {
                RecordsScreen(
                    onBackClick = {
                        navController.popBackStack()
                    }
                )
            }

            composable(Screen.Gallery.route) {
                GalleryScreen(
                    onBackClick = {
                        navController.popBackStack()
                    }
                )
            }

            composable(Screen.LiveStream.route) {
                SimpleLiveStreamScreen(
                    wearablesViewModel = wearablesViewModel,
                    onBackClick = {
                        navController.popBackStack()
                    }
                )
            }

            composable(Screen.RTMPStream.route) {
                RTMPStreamingScreen(
                    onBackClick = {
                        navController.popBackStack()
                    }
                )
            }
        }
    }
}
