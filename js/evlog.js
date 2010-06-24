evlog = {
	_socket:	null,
	event: function(){},		// Initially defined as a nop
	_sourcename: '',
	host: null,
	port: null,

	connected: function() {
		return this._socket !== null;
	},

	on_connect: function(cb) {
		this._connect_cb = cb;
	},

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
			host: this.host,
			port: this.port
		});

		this._socket.received = function(data) {
			self._receive_raw(data);
		};

		this._socket.signals.connected.attach_output(function(newstate) {
			self._connected_changed(newstate);
		});
	},

	log: console.log,
	_receive_raw: function(data){},
	_msg_id: 1,

	send: function() {
		this._socket.send(
			Utf8.encode(
				serialize_tcl_list(arguments)
			)
		);
	},

	_connected_changed: function(newstate){
		if (newstate) {
			this.send('init', this._sourcename, 'servertime');
			this.event = function(type, details) {
				if (typeof details == 'undefined') {
					details = '';
				}
				this.send('ev', '-1', type, details);
			};
			if (this.on_connect !== null) {
				this.on_connect();
			}
		}
	}
};

// vim: ft=javascript foldmethod=marker foldmarker=<<<,>>> ts=4 shiftwidth=4
