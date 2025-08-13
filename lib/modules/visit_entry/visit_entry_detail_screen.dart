import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

// Audio Player Widget Implementation (unchanged)
class AudioPlayerWidget extends StatefulWidget {
  final String source;
  final Function? onDelete;
  final bool isDelete;
  final String duration;
  final dynamic addVisitViewModel;

  const AudioPlayerWidget({
    Key? key,
    required this.source,
    this.onDelete,
    required this.isDelete,
    required this.duration,
    this.addVisitViewModel,
  }) : super(key: key);

  @override
  _AudioPlayerWidgetState createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  final _audioPlayer = AudioPlayer();
  String? _localFilePath;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initAudioPlayer();
  }

  Future<void> _initAudioPlayer() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse(widget.source),
        headers: {'Cookie': 'sid=${widget.addVisitViewModel?.sid ?? ''}'},
      );

      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File(
          '${tempDir.path}/temp_audio_${DateTime.now().millisecondsSinceEpoch}.mp3',
        );
        await tempFile.writeAsBytes(response.bodyBytes);
        setState(() {
          _localFilePath = tempFile.path;
        });

        await _audioPlayer.setFilePath(_localFilePath!);
        setState(() {
          _isLoading = false;
        });
      } else {
        throw Exception(
            'Failed to download audio file: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error loading audio: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    if (_localFilePath != null) {
      File(_localFilePath!).delete().catchError((e) {});
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xff65C18C)))
            : _errorMessage != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Audio Unavailable',
                        style: TextStyle(
                          color: Color(0xff555555),
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Color(0xff555555),
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _errorMessage = null;
                            _isLoading = false;
                            _localFilePath = null;
                          });
                          _initAudioPlayer();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff65C18C),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Retry',
                            style: TextStyle(fontFamily: 'Poppins')),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          StreamBuilder<PlayerState>(
                            stream: _audioPlayer.playerStateStream,
                            builder: (context, snapshot) {
                              final playerState = snapshot.data;
                              final processingState =
                                  playerState?.processingState;
                              final playing = playerState?.playing;
                              if (processingState == ProcessingState.loading ||
                                  processingState ==
                                      ProcessingState.buffering) {
                                return const SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.0,
                                      color: Color(0xff65C18C),
                                    ),
                                  ),
                                );
                              } else if (playing != true) {
                                return IconButton(
                                  icon: Icon(
                                    Icons.play_circle,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    size: 40,
                                  ),
                                  onPressed: _audioPlayer.play,
                                );
                              } else if (processingState !=
                                  ProcessingState.completed) {
                                return IconButton(
                                  icon: const Icon(
                                    Icons.pause_circle,
                                    color: Color(0xff555555),
                                    size: 40,
                                  ),
                                  onPressed: _audioPlayer.pause,
                                );
                              } else {
                                return IconButton(
                                  icon: Icon(
                                    Icons.replay_circle_filled,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    size: 40,
                                  ),
                                  onPressed: () {
                                    _audioPlayer.seek(Duration.zero);
                                    _audioPlayer.play();
                                  },
                                );
                              }
                            },
                          ),
                          Expanded(
                            child: StreamBuilder<Duration?>(
                              stream: _audioPlayer.durationStream,
                              builder: (context, snapshot) {
                                final duration = snapshot.data ?? Duration.zero;
                                return StreamBuilder<Duration>(
                                  stream: _audioPlayer.positionStream,
                                  builder: (context, snapshot) {
                                    var position =
                                        snapshot.data ?? Duration.zero;
                                    if (position > duration) {
                                      position = duration;
                                    }
                                    return Slider(
                                      value: position.inSeconds.toDouble(),
                                      min: 0.0,
                                      max: duration.inSeconds.toDouble() > 0
                                          ? duration.inSeconds.toDouble()
                                          : 1.0,
                                      onChanged: (value) async {
                                        final newPosition =
                                            Duration(seconds: value.toInt());
                                        await _audioPlayer.seek(newPosition);
                                      },
                                      activeColor:
                                          Theme.of(context).colorScheme.primary,
                                      inactiveColor: Colors.grey[300],
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.stop,
                                color: Color(0xff555555), size: 30),
                            onPressed: () {
                              _audioPlayer.stop();
                              _audioPlayer.seek(Duration.zero);
                            },
                          ),
                          if (widget.isDelete && widget.onDelete != null)
                            IconButton(
                              icon: const Icon(Icons.delete,
                                  color: Color(0xff555555)),
                              onPressed: () => widget.onDelete!(),
                            ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          StreamBuilder<Duration>(
                            stream: _audioPlayer.positionStream,
                            builder: (context, snapshot) {
                              final position = snapshot.data ?? Duration.zero;
                              return Text(
                                _formatDuration(position),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontFamily: 'Poppins'),
                              );
                            },
                          ),
                          StreamBuilder<Duration?>(
                            stream: _audioPlayer.durationStream,
                            builder: (context, snapshot) {
                              final duration = snapshot.data ?? Duration.zero;
                              return Text(
                                _formatDuration(duration),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontFamily: 'Poppins'),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}

class VisitEntryDetailScreen extends StatefulWidget {
  final String visitEntryName;
  final String serverUrl;
  final String sid;

  const VisitEntryDetailScreen({
    Key? key,
    required this.visitEntryName,
    required this.serverUrl,
    required this.sid,
  }) : super(key: key);

  @override
  _VisitEntryDetailScreenState createState() => _VisitEntryDetailScreenState();
}

class _VisitEntryDetailScreenState extends State<VisitEntryDetailScreen> {
  Map<String, dynamic>? _visitEntry;
  bool _isLoading = true;
  String? _errorMessage;
  int _selectedIndex = 0;
  late PageController _pageController;

  final List<String> _sections = [
    'Visit Details',
    'Customer Info',
    'Follow Up',
    'Attachments',
  ];

  final List<IconData> _sectionIcons = [
    Icons.description,
    Icons.person,
    Icons.schedule,
    Icons.attach_file,
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _fetchVisitEntry();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchVisitEntry() async {
    final url =
        '${widget.serverUrl}/api/resource/Visit Entry/${widget.visitEntryName}';
    final headers = {
      'Cookie': 'sid=${widget.sid}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _visitEntry = data['data'];
          _isLoading = false;
          _errorMessage = null;
        });
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (error) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error fetching visit entry: $error';
      });
    }
  }

  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) return 'N/A';
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return DateFormat('dd-MM-yyyy HH:mm').format(dateTime);
    } catch (e) {
      return dateTimeStr;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd-MM-yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  void _onNavBarTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Widget _buildSectionCard(Widget child) {
    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: child,
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xff65C18C),
        fontFamily: 'Poppins',
      ),
    );
  }

  Widget _buildSubSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Color(0xff65C18C),
          fontFamily: 'Poppins',
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 1,
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context)
                      .colorScheme
                      .onBackground
                      .withOpacity(0.6),
                  fontSize: 14,
                  fontFamily: 'Poppins',
                ),
                textAlign: TextAlign.left,
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                value,
                style: TextStyle(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onBackground,
                  fontFamily: 'Poppins',
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
        Container(
          height: 1,
          margin: const EdgeInsets.symmetric(vertical: 6),
          color: Theme.of(context).colorScheme.onBackground.withOpacity(0.2),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Visit Entry Details',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontFamily: 'Poppins',
              ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xff65C18C)))
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onBackground,
                              fontSize: 18,
                              fontFamily: 'Poppins',
                            ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchVisitEntry,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Retry',
                            style: TextStyle(fontFamily: 'Poppins')),
                      ),
                    ],
                  ),
                )
              : _visitEntry == null
                  ? Center(
                      child: Text(
                        'No data available',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onBackground,
                              fontSize: 18,
                              fontFamily: 'Poppins',
                            ),
                      ),
                    )
                  : Column(
                      children: [
                        Container(
                          height: 70,
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.05),
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            itemCount: _sections.length,
                            itemBuilder: (context, index) {
                              final isSelected = _selectedIndex == index;
                              return GestureDetector(
                                onTap: () => _onNavBarTap(index),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _sectionIcons[index],
                                        color: isSelected
                                            ? Colors.white
                                            : Theme.of(context)
                                                .colorScheme
                                                .primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _sections[index],
                                        style: TextStyle(
                                          color: isSelected
                                              ? Colors.white
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        Expanded(
                          child: PageView(
                            controller: _pageController,
                            onPageChanged: (index) {
                              setState(() {
                                _selectedIndex = index;
                              });
                            },
                            children: [
                              _buildSectionCard(_buildVisitDetailsSection()),
                              _buildSectionCard(_buildCustomerInfoSection()),
                              _buildSectionCard(_buildFollowUpSection()),
                              _buildSectionCard(_buildAttachmentsSection()),
                            ],
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _buildVisitDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Visit Details'),
        const SizedBox(height: 12),
        _buildInfoRow('Visit ID', _visitEntry!['name'] ?? 'N/A', isBold: true),
        _buildInfoRow(
            'Purpose of Visit', _visitEntry!['purpose_of_visit'] ?? 'N/A'),
        _buildInfoRow('Visited Date & Time',
            _formatDateTime(_visitEntry!['visited_date_time'])),
        _buildInfoRow(
            'Handling', _visitEntry!['handling']?.toString() ?? 'N/A'),
        _buildInfoRow('GST', _visitEntry!['gst']?.toString() ?? 'N/A'),
        _buildInfoRow('Freight', _visitEntry!['freight']?.toString() ?? 'N/A'),
        _buildInfoRow('Payment', _visitEntry!['payment']?.toString() ?? 'N/A'),
        _buildInfoRow(
            'Quality Complaint', _visitEntry!['is_qc'] == 1 ? 'Yes' : 'No'),
        _buildInfoRow('Remarks', _visitEntry!['remarks'] ?? 'N/A'),
      ],
    );
  }

  Widget _buildCustomerInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Customer Info'),
        const SizedBox(height: 12),
        _buildInfoRow('Customer Name', _visitEntry!['customer_name'] ?? 'N/A',
            isBold: true),
      ],
    );
  }

  Widget _buildFollowUpSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Follow Up'),
        const SizedBox(height: 12),
        _buildInfoRow(
            'Follow Up Needed', _visitEntry!['follow_up_needed'] ?? 'N/A'),
        if (_visitEntry!['follow_up_needed']?.toLowerCase() == 'yes') ...[
          _buildInfoRow('Purpose of Next Visit',
              _visitEntry!['purpose_of_next_visit'] ?? 'N/A'),
          _buildInfoRow(
              'Follow Up Date', _formatDate(_visitEntry!['follow_up_date'])),
        ],
        if (_visitEntry!['follow_up_needed']?.toLowerCase() != 'yes')
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No follow-up required.',
              style: TextStyle(
                color: Color(0xff555555),
                fontFamily: 'Poppins',
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAttachmentsSection() {
    final hasAudio = _visitEntry!['audio_recording']?.isNotEmpty ?? false;
    final hasImage = _visitEntry!['image_attachment']?.isNotEmpty ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Attachments'),
        const SizedBox(height: 12),
        if (hasAudio) ...[
          _buildInfoRow('Audio Recording', 'Play Audio'),
          const SizedBox(height: 8),
          AudioPlayerWidget(
            source: '${widget.serverUrl}${_visitEntry!['audio_recording']}',
            onDelete: null,
            isDelete: false,
            duration: _visitEntry!['audio_duration']?.toString() ?? '0',
            addVisitViewModel: widget,
          ),
          const SizedBox(height: 16),
        ],
        if (hasImage) ...[
          _buildInfoRow('Image Attachment', 'View Image'),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              '${widget.serverUrl}${_visitEntry!['image_attachment']}',
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xff65C18C)),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: double.infinity,
                  height: 200,
                  color: Colors.grey[300],
                  child: const Center(
                    child: Text(
                      'Error loading image',
                      style: TextStyle(
                        color: Color(0xff555555),
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        if (!hasAudio && !hasImage)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No attachments available.',
              style: TextStyle(
                color: Color(0xff555555),
                fontFamily: 'Poppins',
              ),
            ),
          ),
      ],
    );
  }
}
