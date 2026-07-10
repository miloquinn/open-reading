// 文件说明：核心基础设施聚合导出文件，统一暴露数据库、缓存和备份服务。
// 技术要点：服务层、Barrel Export。

// Core services barrel.
//
// 作用：集中导出应用级基础服务，减少页面层 import 噪音。
export 'package:xxread/services/core/app_settings_service.dart';
export 'package:xxread/services/core/app_state_service.dart';
export 'package:xxread/services/core/data_backup_service.dart';
export 'package:xxread/services/core/data_cache_service.dart';
export 'package:xxread/services/core/data_service.dart';
export 'package:xxread/services/core/database_service.dart';
export 'package:xxread/services/core/enhanced_database_service.dart';
export 'package:xxread/services/core/offline_data_service.dart';
export 'package:xxread/services/core/share_service.dart';
