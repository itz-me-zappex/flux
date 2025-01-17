pkgname='flux'
pkgver='1.20.1'
pkgrel='1'
pkgdesc='Advanced daemon for X11 desktops and window managers, designed to automatically limit FPS/CPU usage of unfocused windows and run commands on focus and unfocus events. Written in Bash and C++.'
arch=('any')
url='https://github.com/itz-me-zappex/flux'
license=('GPL-3.0-only')
makedepends=(
	'libxres'
	'libx11'
	'libxext'
	'xorgproto'
	'gcc'
	'make'
)
depends=(
	'bash'
	'util-linux'
	'cpulimit'
	'coreutils'
	'libxres'
	'libx11'
	'libxext'
	'xorgproto'
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