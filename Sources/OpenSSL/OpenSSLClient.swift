import Async
import COpenSSL
import TCP
import TLS

/// A TLS client implemented by COpenSSL.
public final class OpenSSLClient: TLSClient {
    /// The TLS socket.
    public let socket: OpenSSLSocket

    /// See TLSClient.settings
    public var settings: TLSClientSettings

    /// Underlying TCP client.
    private let tcp: TCPClient

    /// Create a new `OpenSSLClient`
    public init(tcp: TCPClient, using settings: TLSClientSettings) throws {
        let socket = try OpenSSLSocket(tcp: tcp.socket, method: .tls1_2, side: .client)
        self.settings = settings
        self.socket = socket
        self.tcp = tcp
    }

    /// See TLSClient.connect
    public func connect(hostname: String, port: UInt16) throws {
        try tcp.connect(hostname: hostname, port: port)
        try hostname.withCString { cHostname in
            let res = SSL_set_tlsext_host_name(socket.cSSL, cHostname)
            guard res == 1 else {
                throw socket.makeError(status: res, identifier: "sni", source: .capture())
            }
        }
        let res = SSL_connect(socket.cSSL)
        switch SSL_get_error(socket.cSSL, res) {
        case SSL_ERROR_WANT_READ, SSL_ERROR_WANT_WRITE, SSL_ERROR_WANT_CONNECT: break // wouldblock
        default: throw socket.makeError(status: res, identifier: "connect", source: .capture())
        }
    }

    /// See TLSClient.close
    public func close() {
        socket.close()
        tcp.close()
    }
}
