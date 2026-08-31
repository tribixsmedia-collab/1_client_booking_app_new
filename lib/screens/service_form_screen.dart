import '../utils/breakpoints.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme.dart';

class ServiceFormScreen extends StatefulWidget {
  final Map<String, dynamic> form;
  final String categoryName;
  final bool returnDataOnly;
  final List<Map<String, dynamic>>? prefillData;

  const ServiceFormScreen({
    super.key,
    required this.form,
    required this.categoryName,
    this.returnDataOnly = false,
    this.prefillData,
  });

  @override
  State<ServiceFormScreen> createState() => _ServiceFormScreenState();
}

class _ServiceFormScreenState extends State<ServiceFormScreen> {
  late List<dynamic> _steps;
  int _currentStep = 0;
  final Map<int, dynamic> _answers = {};
  final _customController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _steps = widget.form['steps'] as List<dynamic>;
    _loadPrefill();
  }

  void _loadPrefill() {
    if (widget.prefillData == null) return;
    for (final response in widget.prefillData!) {
      final stepId = response['step_id'];
      final answer = response['answer'];
      if (stepId != null && answer != null) {
        final answerStr = answer.toString();
        // Check if this step is multi_select
        final step = _steps.firstWhere(
          (s) => s['id'] == stepId,
          orElse: () => null,
        );
        if (step != null && step['field_type'] == 'multi_select') {
          _answers[stepId] = answerStr.split(', ').toList();
        } else {
          _answers[stepId] = answerStr;
        }
      }
    }
  }

  Map<String, dynamic> get _currentStepData =>
      Map<String, dynamic>.from(_steps[_currentStep]);

  bool get _isLastStep => _currentStep == _steps.length - 1;

  bool get _canProceed {
    final step = _currentStepData;
    final isRequired = step['is_required'] == true;
    if (!isRequired) return true;

    final answer = _answers[step['id']];
    if (answer == null) return false;
    if (answer is String && answer.trim().isEmpty) return false;
    if (answer is List && answer.isEmpty) return false;
    return true;
  }

  void _selectSingle(int stepId, String value) {
    setState(() => _answers[stepId] = value);
  }

  void _toggleMulti(int stepId, String value) {
    setState(() {
      final list = List<String>.from((_answers[stepId] as List?) ?? []);
      if (list.contains(value)) {
        list.remove(value);
      } else {
        list.add(value);
      }
      _answers[stepId] = list;
    });
  }

  void _addCustomOption(int stepId, String fieldType) {
    final text = _customController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      if (fieldType == 'single_select') {
        _answers[stepId] = text;
      } else {
        final list = List<String>.from((_answers[stepId] as List?) ?? []);
        if (!list.contains(text)) list.add(text);
        _answers[stepId] = list;
      }
      _customController.clear();
    });
  }

  void _nextStep() {
    if (!_canProceed) {
      setState(() => _errorMessage = 'Please select an option to continue.');
      return;
    }
    setState(() => _errorMessage = null);

    if (_isLastStep) {
      _submitForm();
    } else {
      setState(() => _currentStep++);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _errorMessage = null;
      });
    }
  }

  Future<void> _submitForm() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final responses = _steps.map((step) {
      final answer = _answers[step['id']];
      return {
        'step_id': step['id'],
        'title': step['title'],
        'answer': answer is List ? answer.join(', ') : (answer ?? ''),
      };
    }).toList();

    // Return data only mode — don't submit to API
    if (widget.returnDataOnly) {
      if (!mounted) return;
      Navigator.of(context).pop(responses);
      return;
    }

    // Submit to API mode
    try {
      final submissionId = await ApiService.submitForm(
        formId: widget.form['id'],
        responses: responses,
      );

      if (!mounted) return;
      Navigator.of(context).pop(submissionId);
    } catch (e) {
      setState(
        () => _errorMessage = e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final step = _currentStepData;
    final stepId = step['id'] as int;
    final fieldType = step['field_type'] as String;
    final options = (step['options'] as List<dynamic>?) ?? [];
    final allowCustom = step['allow_custom'] == true;
    final progress = (_currentStep + 1) / _steps.length;

    return Scaffold(
      body: DesktopCentered(
        maxWidth: kDesktopFormWidth,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  children: [
                    Text(
                      'STEP ${_currentStep + 1} OF ${_steps.length}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey.shade200,
                    color: AppColors.primary,
                    minHeight: 4,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Category header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primaryDark,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            widget.categoryName.isNotEmpty
                                ? widget.categoryName[0].toUpperCase()
                                : 'S',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CATEGORY',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textGrey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            widget.categoryName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Question
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    Text(
                      step['title'],
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if ((step['description'] as String?)?.isNotEmpty ??
                        false) ...[
                      const SizedBox(height: 4),
                      Text(
                        step['description'],
                        style: const TextStyle(
                          color: AppColors.textGrey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),

                    // Field based on type
                    if (fieldType == 'single_select')
                      ...options.map((opt) {
                        final label = opt['label'] as String;
                        final isSelected = _answers[stepId] == label;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: GestureDetector(
                            onTap: () => _selectSingle(stepId, label),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : Colors.grey.shade300,
                                  width: isSelected ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                color: isSelected
                                    ? AppColors.primary.withValues(alpha: 0.05)
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        color: isSelected
                                            ? AppColors.primary
                                            : Colors.black,
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(
                                      Icons.check_circle,
                                      color: AppColors.primary,
                                      size: 22,
                                    )
                                  else
                                    Icon(
                                      Icons.circle_outlined,
                                      color: Colors.grey.shade400,
                                      size: 22,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),

                    if (fieldType == 'multi_select')
                      ...options.map((opt) {
                        final label = opt['label'] as String;
                        final selected =
                            (_answers[stepId] as List?)?.contains(label) ??
                            false;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: GestureDetector(
                            onTap: () => _toggleMulti(stepId, label),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: selected
                                      ? AppColors.primary
                                      : Colors.grey.shade300,
                                  width: selected ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                color: selected
                                    ? AppColors.primary.withValues(alpha: 0.05)
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: selected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        color: selected
                                            ? AppColors.primary
                                            : Colors.black,
                                      ),
                                    ),
                                  ),
                                  if (selected)
                                    const Icon(
                                      Icons.check_box,
                                      color: AppColors.primary,
                                      size: 22,
                                    )
                                  else
                                    Icon(
                                      Icons.check_box_outline_blank,
                                      color: Colors.grey.shade400,
                                      size: 22,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),

                    if (fieldType == 'text')
                      TextField(
                        onChanged: (v) => setState(() => _answers[stepId] = v),
                        decoration: InputDecoration(
                          hintText: 'Type your answer...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        maxLines: 3,
                      ),

                    if (fieldType == 'number')
                      TextField(
                        onChanged: (v) => setState(() => _answers[stepId] = v),
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'Enter a number...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),

                    // Custom option input
                    if (allowCustom &&
                        (fieldType == 'single_select' ||
                            fieldType == 'multi_select')) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _customController,
                              decoration: InputDecoration(
                                hintText: 'Type custom option...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _addCustomOption(stepId, fieldType),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _customController.clear(),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.close),
                            ),
                          ),
                        ],
                      ),
                    ],

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ],
                ),
              ),

              // Bottom buttons
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      if (_currentStep > 0)
                        OutlinedButton.icon(
                          onPressed: _previousStep,
                          icon: const Icon(Icons.chevron_left, size: 18),
                          label: const Text('Back'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        )
                      else
                        OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.chevron_left, size: 18),
                          label: const Text('Back'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _nextStep,
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : null,
                        label: Text(_isLastStep ? 'Submit' : 'Continue'),
                        iconAlignment: _isLastStep
                            ? IconAlignment.start
                            : IconAlignment.end,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
