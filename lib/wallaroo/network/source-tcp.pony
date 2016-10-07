use "net"
use "time"
use "buffered"
use "collections"
use "sendence/bytes"
use "wallaroo/metrics"
use "wallaroo/topology"

class SourceNotify is TCPConnectionNotify
  let _source: BytesProcessor
  var _header: Bool = true
  var _msg_count: USize = 0

  new iso create(source: BytesProcessor iso) =>
    _source = consume source

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso): Bool =>
    if _header then
      try
        let expect = Bytes.to_u32(data(0), data(1), data(2), data(3)).usize()

        conn.expect(expect)
        _header = false
      end
    else
      _source.process(consume data)

      conn.expect(4)
      _header = true
    end
    ifdef linux then
      _msg_count = _msg_count + 1
      if ((_msg_count % 50) == 0) then
        false
      else
        true
      end
    else
      false
    end

  fun ref accepted(conn: TCPConnection ref) =>
    @printf[None]("accepted\n".cstring())
    conn.expect(4)

  fun ref connected(sock: TCPConnection ref) =>
    @printf[None]("incoming connected\n".cstring())

class SourceListenerNotify[In: Any val] is TCPListenNotify
  let _source_builder: {(): BytesProcessor iso^} val
  let _metrics: JrMetrics
  let _expected: USize

  new iso create(source_builder: {(): BytesProcessor iso^} val,
    metrics: JrMetrics, expected: USize) 
  =>
    _source_builder = source_builder
    _metrics = metrics
    _expected = expected

  fun ref connected(listen: TCPListener ref): TCPConnectionNotify iso^ =>
    SourceNotify(Source[In](_source_builder(), _metrics, 
      _expected))

  fun ref listening(listen: TCPListener ref) =>
    try
      (let host, let service) = listen.local_address().name()
      @printf[I32](("Source: listening on " + host + ":" + service + "\n").cstring())
    else
      @printf[I32]("Source: couldn't get local address\n".cstring())
      listen.close()
    end