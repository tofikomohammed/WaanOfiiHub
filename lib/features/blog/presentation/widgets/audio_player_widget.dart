import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class AudioPlayerWidget extends StatefulWidget {
  final String audioUrl;
  final String? title;

  const AudioPlayerWidget({super.key, required this.audioUrl, this.title});

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  late AudioPlayer _player;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      final dur = await _player.setUrl(widget.audioUrl);
      if (dur != null && mounted) {
        setState(() => _duration = dur);
      }
    } catch (_) {}

    _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state.playing);
      }
    });

    _player.positionStream.listen((pos) {
      if (mounted) {
        setState(() => _position = pos);
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.title != null) ...[
            Text(widget.title!, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
          ],
          Row(
            children: [
              IconButton(
                icon: Icon(
                  _isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                ),
                iconSize: 42,
                color: theme.colorScheme.primary,
                onPressed: () {
                  if (_isPlaying) {
                    _player.pause();
                  } else {
                    _player.play();
                  }
                },
              ),
              Expanded(
                child: Slider(
                  value: _position.inMilliseconds.toDouble().clamp(
                    0.0,
                    _duration.inMilliseconds.toDouble() > 0
                        ? _duration.inMilliseconds.toDouble()
                        : 1.0,
                  ),
                  max: _duration.inMilliseconds.toDouble() > 0
                      ? _duration.inMilliseconds.toDouble()
                      : 1.0,
                  onChanged: (val) {
                    _player.seek(Duration(milliseconds: val.toInt()));
                  },
                ),
              ),
              Text(
                '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
