pkgname='flux'
pkgver='1.19.1'
pkgrel='1'
pkgdesc='A daemon for X11 designed to automatically limit FPS or CPU usage of unfocused windows and run commands on focus and unfocus events.'
arch=('any')
url='https://github.com/itz-me-zappex/flux'
license=('GPL-3.0-only')
makedepends=(
	'libxres'
	'libx11'
	'gcc'
	'make'
)
depends=(
	'bash'
	'util-linux'
	'cpulimit'
	'coreutils'
	'xorg-xprop'
	'xorg-xwininfo'
	'libxres'
	'libx11'
)
optdepends=(
	'mangohud: support for FPS limits'
	'lib32-mangohud: support for FPS limits (32-bit)'
	'libnotify: support for notifications'
	'xdotool: minimize borderless windows on unfocus'
)
source=("${url}/archive/refs/tags/v${pkgver}.tar.gz")
sha256sums=('SKIP')

build(){
	cd "${srcdir}/${pkgname}-${pkgver}"
	make
}

package(){
	cd "${srcdir}/${pkgname}-${pkgver}"
	PREFIX="${pkgdir}/usr" make install
}