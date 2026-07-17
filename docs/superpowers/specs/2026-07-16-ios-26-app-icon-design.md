# iOS 26 App Icon Design
## Goal

Adapt the supplied `origo-community-icon-v4-source.png` artwork into a larger native Icon Composer icon without redrawing or restyling it.

## Source of truth

`/Users/xiaoyuan/work/Origo-Reader/xxread-next/public/branding/origo-community-icon-v4-source.png`

The supplied image controls the composition, colors, book illustration, star, highlights, and shadows. The implementation may only remove the connected light background, resize the canvas, and separate the existing star and book into layers.

## Icon Composer structure

- A warm system-light gradient background.
- A book artwork layer retaining the source image at its existing proportions.
- A separate star layer retaining its original position and proportions.
- Automatic Default, Dark, and Mono treatments from Icon Composer.

## Integration and fallback

- Add the native package at `ios/Runner/AppIcon.icon` under the `AppIcon` name.
- Keep the existing asset catalog for older Xcode versions.
- Use a 1024 x 1024 alpha-free resize of the supplied source as `assets/images/app_icon.png` and regenerate the existing iOS raster sizes from it.
- Leave Android icon sources unchanged.
