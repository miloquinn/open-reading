// 文件说明：按平台导出用户字体服务。

export 'custom_font_models.dart';
export 'custom_font_service_io.dart'
    if (dart.library.html) 'custom_font_service_web.dart';
