class Rocksdb < Formula
  desc "Embeddable, persistent key-value store for fast storage"
  homepage "https://rocksdb.org/"
  url "https://github.com/facebook/rocksdb/archive/v6.14.6.tar.gz"
  sha256 "fa61c55735a4911f36001a98aa2f5df1ffe4b019c492133d0019f912191209ce"
  license "GPL-2.0"

  bottle do
    cellar :any
    sha256 "4766a17ad98408c1dfd3959d09e2e14fa252bd8a6fc1513973177d79330a9e85" => :big_sur
    sha256 "4c1fa784b95465e6fd4cde80be2df2a4df8713d5692a5c8055ae9ff9269ae5f8" => :catalina
    sha256 "8e8b8df18fac301541221bfa8dc995773592e7fcd07de3ffd03cdb66bbfb9936" => :mojave
  end

  depends_on "cmake" => :build
  depends_on "gflags"
  depends_on "lz4"
  depends_on "snappy"
  depends_on "zstd"

  uses_from_macos "bzip2"
  uses_from_macos "zlib"

  # Add artifact suffix to shared library
  # https://github.com/facebook/rocksdb/pull/7755
  patch do
    url "https://github.com/facebook/rocksdb/commit/98f3f3143007bcb5455105a05da7eeecc9cf53a0.patch?full_index=1"
    sha256 "6fb59cd640ed8c39692855115b72e8aa8db50a7aa3842d53237e096e19f88fc1"
  end

  def install
    ENV.cxx11
    args = std_cmake_args
    args << "-DPORTABLE=ON"
    args << "-DUSE_RTTI=ON"
    args << "-DWITH_BENCHMARK_TOOLS=OFF"

    # build regular rocksdb
    system "cmake", ".", *args
    system "make", "install"

    cd "tools" do
      bin.install "sst_dump" => "rocksdb_sst_dump"
      bin.install "db_sanity_test" => "rocksdb_sanity_test"
      bin.install "write_stress" => "rocksdb_write_stress"
      bin.install "ldb" => "rocksdb_ldb"
      bin.install "db_repl_stress" => "rocksdb_repl_stress"
      bin.install "rocksdb_dump"
      bin.install "rocksdb_undump"
    end
    bin.install "db_stress_tool/db_stress" => "rocksdb_stress"

    # build rocksdb_lite
    args << "-DROCKSDB_LITE=ON"
    args << "-DARTIFACT_SUFFIX=_lite"
    args << "-DWITH_CORE_TOOLS=OFF"
    args << "-DWITH_TOOLS=OFF"
    system "make", "clean"
    system "cmake", ".", *args
    system "make", "install"
  end

  test do
    (testpath/"test.cpp").write <<~EOS
      #include <assert.h>
      #include <rocksdb/options.h>
      #include <rocksdb/memtablerep.h>
      using namespace rocksdb;
      int main() {
        Options options;
        return 0;
      }
    EOS

    system ENV.cxx, "test.cpp", "-o", "db_test", "-v",
                                "-std=c++11", "-stdlib=libc++", "-lstdc++",
                                "-lz", "-lbz2",
                                "-L#{lib}", "-lrocksdb_lite",
                                "-DROCKSDB_LITE=1",
                                "-L#{Formula["snappy"].opt_lib}", "-lsnappy",
                                "-L#{Formula["lz4"].opt_lib}", "-llz4",
                                "-L#{Formula["zstd"].opt_lib}", "-lzstd"
    system "./db_test"

    assert_match "sst_dump --file=", shell_output("#{bin}/rocksdb_sst_dump --help 2>&1")
    assert_match "rocksdb_sanity_test <path>", shell_output("#{bin}/rocksdb_sanity_test --help 2>&1", 1)
    assert_match "rocksdb_stress [OPTIONS]...", shell_output("#{bin}/rocksdb_stress --help 2>&1", 1)
    assert_match "rocksdb_write_stress [OPTIONS]...", shell_output("#{bin}/rocksdb_write_stress --help 2>&1", 1)
    assert_match "ldb - RocksDB Tool", shell_output("#{bin}/rocksdb_ldb --help 2>&1")
    assert_match "rocksdb_repl_stress:", shell_output("#{bin}/rocksdb_repl_stress --help 2>&1", 1)
    assert_match "rocksdb_dump:", shell_output("#{bin}/rocksdb_dump --help 2>&1", 1)
    assert_match "rocksdb_undump:", shell_output("#{bin}/rocksdb_undump --help 2>&1", 1)
  end
end
