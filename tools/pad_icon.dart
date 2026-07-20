import 'dart:io';
import 'package:image/image.dart';

void main() {
  final src = decodeImage(File('assets/brand/fendo_icon.png').readAsBytesSync())!;
  const size = 1024;
  const pad = 200;
  final fg = Image(width: size, height: size, numChannels: 4);
  fill(fg, color: ColorRgba8(0, 0, 0, 0));
  final inner = size - pad * 2;
  final resized = copyResize(
    src,
    width: inner,
    height: inner,
    interpolation: Interpolation.cubic,
  );
  compositeImage(fg, resized, dstX: pad, dstY: pad);
  File('assets/brand/fendo_adaptive_fg.png').writeAsBytesSync(encodePng(fg));
  print('wrote assets/brand/fendo_adaptive_fg.png pad=$pad');
}
