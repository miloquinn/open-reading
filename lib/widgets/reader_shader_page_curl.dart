import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../core/reader/reader_page_turn_geometry.dart';
import 'reader_paper_page_leaf.dart';

part 'src/page_curl/reader_page_curl_api.dart';
part 'src/page_curl/reader_page_curl_internal_types.dart';
part 'src/page_curl/reader_page_curl_painters.dart';
part 'src/page_curl/reader_page_curl_settle.dart';
part 'src/page_curl/reader_page_curl_snapshot_cache.dart';
part 'src/page_curl/reader_page_curl_state.dart';
