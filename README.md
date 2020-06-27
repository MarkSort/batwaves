# Bat Waves
> An experiment using WebRTC for multiplayer game updates

This game uses WebRTC DataChannels to provide multiplayer updates via unordered and unreliable packets. This works with modern browsers where WebRTC
is supported but raw UDP packets are not.

You can try it at http://batwaves.marksort.com/

## Developing
### WebRTC Plugin
To run the game natively you must download the release and debug builds of the Godot WebRTC plugin. Extract them into the `/godot/` directory and you
should end up with `/godot/webrtc/` and `/godot/webrtc_debug/` directories. Bat Waves was developed and tested with the 
[0.3 release](https://github.com/godotengine/webrtc-native/releases/tag/0.3).

### HTML version with Godot HTTP Server
Multiplayer may not work in some browsers when using the built-in Godot HTTP server. A python script is included for serving the exported HTML build.
You should connect to it via a non-localhost address.

    cd godot/build/html
    python ../serve-html.py

## Limitations
The signal server for Bat Waves currently runs on the host.  This means we don't get the firewall hole punching benefits of WebRTC.
Also the HTML version can not run a signal server, so it can not host games. A public signal server would allow these, but is currently out of
scope.

## HeartBeast
This game is based on the end result of HeartBeast's Action RPG tutorial series.
* [YouTube Playlist](https://www.youtube.com/playlist?list=PL9FzW-m48fn2SlrW0KoLT4n5egNdX-W9a)
* [GitHub Repo](https://github.com/uheartbeast/youtube-tutorials/tree/87eba5bf8f7796029c39033b107b064e2969bbad/Action%20RPG)

## License

Bat Waves is provided under the MIT License. 
