// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

void main() {
  const defaultStyle = TextStyle(
    color: Colors.blue,
    fontSize: 130,
    shadows: [
      Shadow(
        blurRadius: 0,
        color: Colors.red,
        offset: Offset(10, 0),
      ),
    ],
  );
  runApp(
      DefaultTextStyle(
          style: defaultStyle,
          child: const Center(child: Text('Hello, world!', textDirection: TextDirection.ltr))
      )
  );
}
