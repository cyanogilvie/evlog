/*global define, io */
/*jslint nomen: true, plusplus: true, white: true, browser: true, node: true, newcap: true, continue: true */

define([
	'tcl/list',
	'webtoolkit/utf8'
], function(
	tcllist,
	Utf8
) {
	"use strict";

	var _socket = null,
		_sourcename = null,
		_connect_cb = null,
		iface;

	function send() {
		_socket.send(Utf8.encode(tcllist.array2list(arguments)));
	}

	function send_event(type, details) {
		send('ev', '-1', type, details === undefined ? '' : details);
	}

	function connected_changed(newstate){
		if (newstate) {
			send('init', _sourcename, 'servertime');
			iface.event = send_event;
			if (iface.on_connect !== null) {
				iface.on_connect();
			}
		}
	}

	iface = {
		event: function(){},		// Initially defined as a nop
		host: null,
		port: null,

		connected: function() {
			return _socket !== null;
		},

		on_connect: function(cb) {
			_connect_cb = cb;
		},

		connect: function(sourcename, host, port) {
			var self;

			_sourcename = sourcename;

			if (host === undefined) {
				host = '127.0.0.1';
			}
			if (port === undefined) {
				port = 7200;
			}
			this.host = host;
			this.port = port;

			_socket = io.connect('http://'+this.host+':'+this.port);

			_socket.on('connect', function(){
				self.connected_changed(true);
			});
			_socket.on('disconnect', function(){
				self.connected_changed(false);
			});
		}
	};

	return iface;
});
