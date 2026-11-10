class LibinotifyKqueue < Formula
  desc "Linux inotify API on kqueue, with IN_CLOSE_WRITE emulation on macOS"
  homepage "https://github.com/SoftTransistor/libinotify-kqueue"
  url "https://github.com/SoftTransistor/libinotify-kqueue/archive/refs/tags/20240724-macos1.tar.gz"
  version "20240724-macos1"
  sha256 "638526deb0132412384988b70b260cbeffd01fc54daa182eae646d2d13965257"
  license "MIT"

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "libtool" => :build
  depends_on :macos

  def install
    system "autoreconf", "--force", "--install", "--verbose"
    system "./configure", *std_configure_args
    system "make", "install"
  end

  test do
    # Write to a watched file and expect the emulated IN_CLOSE_WRITE
    (testpath/"test.c").write <<~C
      #include <poll.h>
      #include <stdio.h>
      #include <unistd.h>
      #include <sys/inotify.h>

      int main(void)
      {
          FILE *f = fopen("watched", "w");
          fclose(f);

          int fd = inotify_init();
          if (fd < 0 || inotify_add_watch(fd, "watched", IN_CLOSE_WRITE) < 0)
              return 1;

          f = fopen("watched", "w");
          fputs("data", f);
          fclose(f);

          struct pollfd p = { .fd = fd, .events = POLLIN };
          char buf[4096];
          if (poll(&p, 1, 3000) <= 0 || read(fd, buf, sizeof buf) <= 0)
              return 2;
          return ((struct inotify_event *)buf)->mask & IN_CLOSE_WRITE ? 0 : 3;
      }
    C
    system ENV.cc, "test.c", "-I#{include}", "-L#{lib}", "-linotify", "-o", "test"
    system "./test"
  end
end
