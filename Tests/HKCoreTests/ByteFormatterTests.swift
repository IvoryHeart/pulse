import Testing
@testable import HKCore

@Suite("ByteFormatter")
struct ByteFormatterTests {

    @Test("0 bytes formats as '0 B'")
    func zeroBytes() {
        #expect(ByteFormatter.format(UInt64(0)) == "0 B")
    }

    @Test("Small byte values (< 1024) format as 'N B'")
    func bytesRange() {
        #expect(ByteFormatter.format(UInt64(1)) == "1 B")
        #expect(ByteFormatter.format(UInt64(512)) == "512 B")
        #expect(ByteFormatter.format(UInt64(1023)) == "1023 B")
    }

    @Test("Exact 1024 formats as '1 KB'")
    func exactKilobyte() {
        #expect(ByteFormatter.format(UInt64(1024)) == "1 KB")
    }

    @Test("Kilobyte values format as 'N.N KB'")
    func kilobytes() {
        // 1536 = 1.5 KB
        #expect(ByteFormatter.format(UInt64(1536)) == "1.5 KB")
        // 10240 = 10 KB
        #expect(ByteFormatter.format(UInt64(10240)) == "10 KB")
    }

    @Test("Megabyte values format as 'N.N MB'")
    func megabytes() {
        // 1 MB = 1048576
        #expect(ByteFormatter.format(UInt64(1_048_576)) == "1 MB")
        // 1.5 MB = 1572864
        #expect(ByteFormatter.format(UInt64(1_572_864)) == "1.5 MB")
        // 256 MB = 268435456
        #expect(ByteFormatter.format(UInt64(268_435_456)) == "256 MB")
    }

    @Test("Gigabyte values format as 'N.N GB'")
    func gigabytes() {
        // 1 GB = 1073741824
        #expect(ByteFormatter.format(UInt64(1_073_741_824)) == "1 GB")
        // 2.5 GB
        let twoAndHalfGB: UInt64 = 2_684_354_560
        #expect(ByteFormatter.format(twoAndHalfGB) == "2.5 GB")
        // 16 GB
        let sixteenGB: UInt64 = 17_179_869_184
        #expect(ByteFormatter.format(sixteenGB) == "16 GB")
    }

    @Test("Terabyte values format as 'N.N TB'")
    func terabytes() {
        // 1 TB = 1099511627776
        let oneTB: UInt64 = 1_099_511_627_776
        #expect(ByteFormatter.format(oneTB) == "1 TB")
        // 2.5 TB
        let twoAndHalfTB: UInt64 = 2_748_779_069_440
        #expect(ByteFormatter.format(twoAndHalfTB) == "2.5 TB")
    }

    @Test("Int64 overload works for positive values")
    func int64Positive() {
        #expect(ByteFormatter.format(Int64(1_048_576)) == "1 MB")
    }

    @Test("Int64 overload handles negative values as 0")
    func int64Negative() {
        #expect(ByteFormatter.format(Int64(-100)) == "0 B")
    }
}
