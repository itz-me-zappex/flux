pkgname=flux
pkgver=1.5
pkgrel=1
pkgdesc='A daemon for X11 designed to automatically limit CPU usage of unfocused windows and run commands on focus and unfocus events.'
arch=('any')
url='https://github.com/itz-me-zappex/flux'
license=('GPL-3.0-only')
depends=('bash'
'util-linux'
'procps-ng'
'cpulimit'
'coreutils'
'xorg-xprop'
'xorg-xwininfo')
optdepends=('mangohud: support for FPS-limits'
'lib32-mangohud: support for FPS-limits (32-bit games)')
source=("${url}/archive/refs/tags/v${pkgver}.tar.gz")
sha256sums=('6c2d854eddc0e3c9fa9e40d184a21a1ccdd93237451b1958a56159ffc2437b73')

package(){
	cd "$srcdir/$pkgname-$pkgver"
	install -Dm755 flux "$pkgdir/usr/bin/flux"
}
