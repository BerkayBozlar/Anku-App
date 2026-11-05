import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/network/api_client.dart';
import '../clubs/club_models.dart';
import '../clubs/clubs_repository.dart';
import 'event_models.dart';
import 'events_repository.dart';

/// Düzenlenecek etkinliğin güncel hali.
final eventDetailProvider = FutureProvider.autoDispose.family<ClubEvent, int>(
  (ref, id) => ref.watch(eventsRepositoryProvider).get(id),
  retry: (_, _) => null,
);

/// [eventId] verilmezse yeni etkinlik eklenir. Kaydedince sonuç mesajıyla kapanır.
class EventFormScreen extends ConsumerWidget {
  const EventFormScreen({super.key, this.eventId});

  final int? eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = eventId;
    if (id == null) return const _EventForm();

    final event = ref.watch(eventDetailProvider(id));
    return switch (event) {
      AsyncData(:final value) => _EventForm(initial: value),
      AsyncError(:final error) => Scaffold(
        appBar: AppBar(title: const Text('Etkinliği düzenle')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  error is EventsException
                      ? error.message
                      : describeApiError(error),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () => ref.invalidate(eventDetailProvider(id)),
                  child: const Text('Tekrar dene'),
                ),
              ],
            ),
          ),
        ),
      ),
      _ => Scaffold(
        appBar: AppBar(title: const Text('Etkinliği düzenle')),
        body: const Center(child: CircularProgressIndicator()),
      ),
    };
  }
}

class _EventForm extends ConsumerStatefulWidget {
  const _EventForm({this.initial});

  final ClubEvent? initial;

  @override
  ConsumerState<_EventForm> createState() => _EventFormState();
}

class _EventFormState extends ConsumerState<_EventForm> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.initial?.title);
  late final _description = TextEditingController(
    text: widget.initial?.description,
  );
  late final _capacity = TextEditingController(
    text: widget.initial?.capacity?.toString(),
  );
  late int? _clubId = widget.initial?.clubId;
  late DateTime? _date = widget.initial?.eventDate.toLocal();
  late EventStatus _status = widget.initial?.status ?? EventStatus.published;
  bool _saving = false;
  String? _error;

  bool get _isNew => widget.initial == null;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _capacity.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDateTime(DateTime? current) async {
    final now = DateTime.now();
    final initial = current ?? now.add(const Duration(days: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2, 12, 31),
      helpText: 'Etkinlik tarihi',
    );
    if (date == null || !mounted) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      helpText: 'Etkinlik saati',
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _submit() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    // Kulüpler yüklenemediyse seçim alanı doğrulanamaz
    if (_clubId == null) {
      setState(() => _error = 'Kulüp seçin.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    final description = _description.text.trim();
    final input = EventInput(
      clubId: _clubId!,
      // Konum seçimi kampüs konumları API'si gelince eklenecek; mevcut değer korunur
      campusLocationId: widget.initial?.campusLocationId,
      title: _title.text.trim(),
      description: description.isEmpty ? null : description,
      eventDate: _date!,
      capacity: int.parse(_capacity.text.trim()),
      status: _status,
    );

    try {
      final repository = ref.read(eventsRepositoryProvider);
      final initial = widget.initial;
      if (initial == null) {
        await repository.create(input);
      } else {
        await repository.update(initial.id, input);
      }
      if (!mounted) return;
      Navigator.of(context)
          .pop(_isNew ? 'Etkinlik eklendi.' : 'Etkinlik güncellendi.');
    } on EventsException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Etkinlik ekle' : 'Etkinliği düzenle'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _ClubField(
                    value: _clubId,
                    onChanged: (id) => setState(() => _clubId = id),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _title,
                    decoration: const InputDecoration(
                      labelText: 'Başlık',
                      border: OutlineInputBorder(),
                    ),
                    maxLength: 200,
                    textInputAction: TextInputAction.next,
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? 'Başlık zorunludur.'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _description,
                    decoration: const InputDecoration(
                      labelText: 'Açıklama (isteğe bağlı)',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 2000,
                  ),
                  const SizedBox(height: 8),
                  FormField<DateTime>(
                    initialValue: _date,
                    validator: (value) {
                      if (value == null) return 'Tarih ve saat seçin.';
                      if (value.isBefore(DateTime.now())) {
                        return 'Etkinlik tarihi geçmişte olamaz.';
                      }
                      return null;
                    },
                    builder: (field) => InkWell(
                      onTap: _saving
                          ? null
                          : () async {
                              final picked = await _pickDateTime(field.value);
                              if (picked == null) return;
                              setState(() => _date = picked);
                              field.didChange(picked);
                            },
                      borderRadius: BorderRadius.circular(4),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Tarih ve saat',
                          border: const OutlineInputBorder(),
                          suffixIcon: const Icon(Icons.calendar_month_outlined),
                          errorText: field.errorText,
                        ),
                        isEmpty: field.value == null,
                        child: Text(
                          field.value == null
                              ? ''
                              : formatDateTime(field.value!),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _capacity,
                    decoration: const InputDecoration(
                      labelText: 'Kontenjan',
                      suffixText: 'kişi',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      final capacity = int.tryParse(value?.trim() ?? '');
                      if (capacity == null) return 'Kontenjan zorunludur.';
                      if (capacity <= 0) {
                        return 'Kontenjan sıfırdan büyük olmalıdır.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<EventStatus>(
                    initialValue: _status,
                    decoration: const InputDecoration(
                      labelText: 'Durum',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final status in EventStatus.values)
                        DropdownMenuItem(
                          value: status,
                          child: Text(status.label),
                        ),
                    ],
                    onChanged: (status) {
                      if (status != null) setState(() => _status = status);
                    },
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _saving ? null : _submit,
                    child: _saving
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isNew ? 'Ekle' : 'Kaydet'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kulüp seçimi; kulüpler API'den yüklenir.
class _ClubField extends ConsumerWidget {
  const _ClubField({required this.value, required this.onChanged});

  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clubs = ref.watch(clubsProvider);

    return switch (clubs) {
      AsyncData(value: final List<Club> items) => DropdownButtonFormField<int>(
        // Kulüp listede yoksa (silinmiş vb.) seçim boş gelir
        initialValue: items.any((c) => c.id == value) ? value : null,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'Kulüp',
          border: const OutlineInputBorder(),
          helperText: items.isEmpty
              ? 'Henüz kulüp yok. Kulüpler yönetim portalından eklenir.'
              : null,
        ),
        items: [
          for (final club in items)
            DropdownMenuItem(
              value: club.id,
              child: Text(club.name, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: onChanged,
        validator: (id) => id == null ? 'Kulüp seçin.' : null,
      ),
      AsyncError(:final error) => InputDecorator(
        decoration: InputDecoration(
          labelText: 'Kulüp',
          border: const OutlineInputBorder(),
          errorText: 'Kulüpler yüklenemedi: ${describeApiError(error)}',
          suffixIcon: IconButton(
            tooltip: 'Tekrar dene',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(clubsProvider),
          ),
        ),
        child: const Text(''),
      ),
      _ => const InputDecorator(
        decoration: InputDecoration(
          labelText: 'Kulüp',
          border: OutlineInputBorder(),
          suffixIcon: Padding(
            padding: EdgeInsets.all(12),
            child: SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        child: Text('Kulüpler yükleniyor'),
      ),
    };
  }
}
