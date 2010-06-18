evlog = {
	_socket:	null,
	event: function(){},		// Initially defined as a nop
	_sourcename: '',
	host: null,
	port: null,

	connect: function(sourcename, host, port) {
		var self;
		self = this;

		this._sourcename = sourcename;

		if (typeof host == 'undefined') {
			host = '127.0.0.1';
		}
		if (typeof port == 'undefined') {
			port = 7201;
		}
		this.host = host;
		this.port = port;

		this._socket = new jsSocket({
			keepalive: null,
			logger:	this.log,
			debug: false
		});

		this._socket.onData = function(data) {
			self._receive_raw(data);
		};

		this._socket.onStatus = function(type, val) {
			self._socket_onStatus(type, val);
		};

		this._socket.onLoaded = function(data) {
			console.log('Attempting to connect to '+self.host+':'+self.port);
			self._socket.open(self.host, self.port);
		};
	},

	log: console.log,
	_receive_raw: function(data){},
	_msg_id: 1,

	send: function() {
		this._socket.send(
			Base64.encode(
				Utf8.encode(
					serialize_tcl_list(arguments)
				)
			)
		);
	},

	_socket_onStatus: function(type, val){
		console.log('evlog socket onStatus type: ', type, ', val: ', val);
		switch (type) {
			case 'connecting': break;
			case 'connected':
				this.send('init', this._sourcename, 'servertime');
				this.event = function(type, details) {
					if (typeof details == 'undefined') {
						details = '';
					}
					this.send('ev', '-1', type, details);
				};
				break;
			case 'disconnected':
				break;
			case 'waiting': break;
			case 'failed': break;
			default:
				this.log('Unhandled socket status: "'+type+'"');
				break;
		}
	}
};

// vim: ft=javascript foldmethod=marker foldmarker=<<<,>>> ts=4 shiftwidth=4
