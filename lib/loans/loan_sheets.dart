part of '../main.dart';

@immutable
class LoanStartDateTimeConfiguration {
  const LoanStartDateTimeConfiguration({required this.start});

  final DateTime start;
}

@immutable
class LoanDueDateTimeConfiguration {
  const LoanDueDateTimeConfiguration({required this.dueDate});

  final DateTime? dueDate;
}

@immutable
class LoanInterestConfiguration {
  const LoanInterestConfiguration({
    required this.type,
    required this.period,
    required this.rate,
  });

  final LoanInterestType type;
  final LoanInterestPeriod period;
  final double rate;
}

Future<LoanStartDateTimeConfiguration?> showLoanStartDateTimeConfiguration(
  BuildContext context, {
  required DateTime start,
}) {
  var workingStart = start;

  return showYutakaPopup<LoanStartDateTimeConfiguration>(
    context,
    maxWidth: 470,
    maxHeight: 430,
    child: StatefulBuilder(
      builder: (dialogContext, setModalState) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
          child: YutakaPopupContent(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Time • Date',
                  textAlign: TextAlign.center,
                  style: Theme.of(dialogContext).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 18),
                Text('Start date', style: Theme.of(dialogContext).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 7),
                OutlinedButton.icon(
                  onPressed: () async {
                    final selected = await pickDate(dialogContext, workingStart);
                    if (selected == null || !dialogContext.mounted) return;
                    setModalState(() {
                      workingStart = DateTime(
                        selected.year,
                        selected.month,
                        selected.day,
                        workingStart.hour,
                        workingStart.minute,
                      );
                    });
                  },
                  icon: const Icon(Icons.calendar_today_rounded),
                  label: Text(DateFormat('MMM d, yyyy').format(workingStart)),
                ),
                const SizedBox(height: 14),
                Text('Start time', style: Theme.of(dialogContext).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 7),
                OutlinedButton.icon(
                  onPressed: () async {
                    final selected = await pickTime(dialogContext, TimeOfDay.fromDateTime(workingStart));
                    if (selected == null || !dialogContext.mounted) return;
                    setModalState(() {
                      workingStart = DateTime(
                        workingStart.year,
                        workingStart.month,
                        workingStart.day,
                        selected.hour,
                        selected.minute,
                      );
                    });
                  },
                  icon: const Icon(Icons.schedule_rounded),
                  label: Text(DateFormat('h:mm a').format(workingStart)),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => Navigator.pop(
                    dialogContext,
                    LoanStartDateTimeConfiguration(start: workingStart),
                  ),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

Future<LoanDueDateTimeConfiguration?> showLoanDueDateTimeConfiguration(
  BuildContext context, {
  required DateTime start,
  required DateTime? dueDate,
}) {
  var enabled = dueDate != null;
  var workingDueDate = dueDate ?? start.add(const Duration(days: 30));

  return showYutakaPopup<LoanDueDateTimeConfiguration>(
    context,
    maxWidth: 470,
    maxHeight: 520,
    child: StatefulBuilder(
      builder: (dialogContext, setModalState) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
          child: YutakaPopupContent(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Due date',
                  textAlign: TextAlign.center,
                  style: Theme.of(dialogContext).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 18),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: enabled,
                  onChanged: (value) => setModalState(() => enabled = value),
                  title: const Text('Set a due date', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
                if (enabled) ...[
                  const SizedBox(height: 12),
                  Text('Due date', style: Theme.of(dialogContext).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 7),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final selected = await pickDate(dialogContext, workingDueDate);
                      if (selected == null || !dialogContext.mounted) return;
                      setModalState(() {
                        workingDueDate = DateTime(
                          selected.year,
                          selected.month,
                          selected.day,
                          workingDueDate.hour,
                          workingDueDate.minute,
                        );
                      });
                    },
                    icon: const Icon(Icons.event_available_rounded),
                    label: Text(DateFormat('MMM d, yyyy').format(workingDueDate)),
                  ),
                  const SizedBox(height: 14),
                  Text('Due time', style: Theme.of(dialogContext).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 7),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final selected = await pickTime(dialogContext, TimeOfDay.fromDateTime(workingDueDate));
                      if (selected == null || !dialogContext.mounted) return;
                      setModalState(() {
                        workingDueDate = DateTime(
                          workingDueDate.year,
                          workingDueDate.month,
                          workingDueDate.day,
                          selected.hour,
                          selected.minute,
                        );
                      });
                    },
                    icon: const Icon(Icons.schedule_rounded),
                    label: Text(DateFormat('h:mm a').format(workingDueDate)),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () {
                    if (enabled && workingDueDate.isBefore(start)) {
                      showSnack(dialogContext, 'Due date cannot be before the start date.');
                      return;
                    }
                    Navigator.pop(
                      dialogContext,
                      LoanDueDateTimeConfiguration(dueDate: enabled ? workingDueDate : null),
                    );
                  },
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

Future<LoanInterestConfiguration?> showLoanInterestConfiguration(
  BuildContext context, {
  required LoanInterestType type,
  required LoanInterestPeriod period,
  required double rate,
}) async {
  final rateController = TextEditingController(
    text: rate > 0 ? (rate == rate.roundToDouble() ? rate.toStringAsFixed(0) : rate.toStringAsFixed(2)) : '',
  );
  var workingType = type;
  var workingPeriod = period;

  try {
    return await showYutakaPopup<LoanInterestConfiguration>(
      context,
      maxWidth: 470,
      maxHeight: 590,
      child: StatefulBuilder(
        builder: (dialogContext, setModalState) {
          final rateValue = double.tryParse(rateController.text.trim()) ?? 0;
          return Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
            child: YutakaPopupContent(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Interest',
                    textAlign: TextAlign.center,
                    style: Theme.of(dialogContext).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 18),
                  SleekPillSelector<LoanInterestType>(
                    options: const [
                      SleekPillOption(value: LoanInterestType.none, label: 'None'),
                      SleekPillOption(value: LoanInterestType.simple, label: 'Simple'),
                      SleekPillOption(value: LoanInterestType.compound, label: 'Compound'),
                    ],
                    selected: workingType,
                    onChanged: (value) => setModalState(() {
                      workingType = value;
                      if (value == LoanInterestType.simple && workingPeriod != LoanInterestPeriod.flat) {
                        workingPeriod = LoanInterestPeriod.yearly;
                      }
                    }),
                  ),
                  if (workingType != LoanInterestType.none) ...[
                    const SizedBox(height: 16),
                    TextField(
                      contextMenuBuilder: yutakaTextFieldContextMenu,
                      enableInteractiveSelection: true,
                      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                      controller: rateController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setModalState(() {}),
                      decoration: InputDecoration(
                        labelText: workingPeriod == LoanInterestPeriod.flat ? 'Fixed total interest' : 'Annual interest rate',
                        suffixText: workingPeriod == LoanInterestPeriod.flat ? '% of principal' : '% APR',
                      ),
                    ),
                    const SizedBox(height: 12),
                    SleekCyclePillSelector<LoanInterestPeriod>(
                      options: workingType == LoanInterestType.simple
                          ? const [
                              SleekPillOption(value: LoanInterestPeriod.yearly, label: 'Accrue by day'),
                              SleekPillOption(value: LoanInterestPeriod.flat, label: 'Fixed total'),
                            ]
                          : const [
                              SleekPillOption(value: LoanInterestPeriod.yearly, label: 'Yearly compounding'),
                              SleekPillOption(value: LoanInterestPeriod.monthly, label: 'Monthly compounding'),
                              SleekPillOption(value: LoanInterestPeriod.daily, label: 'Daily compounding'),
                              SleekPillOption(value: LoanInterestPeriod.flat, label: 'Fixed total interest'),
                            ],
                      selected: workingPeriod,
                      onChanged: (value) => setModalState(() => workingPeriod = value),
                    ),
                  ],
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: () {
                      if (!rateValue.isFinite || rateValue < 0 || rateValue > 1000) {
                        showSnack(dialogContext, 'Enter a valid interest rate.');
                        return;
                      }
                      Navigator.pop(
                        dialogContext,
                        LoanInterestConfiguration(
                          type: workingType,
                          period: workingPeriod,
                          rate: workingType == LoanInterestType.none ? 0 : rateValue,
                        ),
                      );
                    },
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  } finally {
    rateController.dispose();
  }
}

Future<void> showLoanEditorSheet(BuildContext context, {Loan? loan, LoanDirection defaultDirection = LoanDirection.lent}) {
  return showYutakaPopup<void>(
    context,
    maxWidth: 600,
    maxHeight: 760,
    barrierDismissible: false,
    child: _LoanEditorSheet(loan: loan, defaultDirection: defaultDirection),
  );
}

class _LoanEditorSheet extends StatefulWidget {
  const _LoanEditorSheet({required this.loan, required this.defaultDirection});

  final Loan? loan;
  final LoanDirection defaultDirection;

  @override
  State<_LoanEditorSheet> createState() => _LoanEditorSheetState();
}

class _LoanEditorSheetState extends State<_LoanEditorSheet> {
  late LoanDirection direction;
  late LoanInterestType interestType;
  late LoanInterestPeriod interestPeriod;
  bool defaultsLoaded = false;
  late DateTime startDate;
  DateTime? dueDate;
  String? contactId;
  String? accountId;
  bool busy = false;
  late final TextEditingController amount;
  late final TextEditingController rate;
  late final TextEditingController note;
  late final TextEditingController newPerson;

  bool get editing => widget.loan != null;

  @override
  void initState() {
    super.initState();
    final loan = widget.loan;
    direction = loan?.direction ?? widget.defaultDirection;
    interestType = loan?.interestType ?? LoanInterestType.none;
    interestPeriod = loan?.interestPeriod ?? LoanInterestPeriod.yearly;
    startDate = loan?.startDate ?? DateTime.now();
    dueDate = loan?.dueDate;
    contactId = loan?.contactId;
    amount = TextEditingController(text: loan == null ? '' : loan.principal.toStringAsFixed(2));
    rate = TextEditingController(text: loan == null || loan.interestRate == 0 ? '' : loan.interestRate.toStringAsFixed(2));
    note = TextEditingController(text: loan?.note ?? '');
    newPerson = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (defaultsLoaded) return;
    final state = context.read<AppController>();
    contactId ??= state.loanContacts.where((contact) => !contact.archived).firstOrNull?.id ?? '__new__';
    if (editing && widget.loan?.disbursalTransactionId != null) {
      final linked = state.transactions
          .where((item) => item.id == widget.loan!.disbursalTransactionId)
          .firstOrNull;
      accountId ??= linked?.fromAccountId;
    }
    accountId ??= state.defaultAccountId ?? state.accounts.firstOrNull?.id;
    defaultsLoaded = true;
  }

  @override
  void dispose() {
    amount.dispose();
    rate.dispose();
    note.dispose();
    newPerson.dispose();
    super.dispose();
  }

  SelectionOption? _contactOption(AppController state) {
    if (contactId == '__new__') {
      return const SelectionOption(id: '__new__', title: 'Add new person', subtitle: 'Create while saving', iconName: 'favorite', iconColor: '#FBC879');
    }
    final contact = state.loanContactOf(contactId);
    return contact == null
        ? null
        : SelectionOption(id: contact.id, title: contact.name, subtitle: contact.phone.isEmpty ? 'Saved person' : contact.phone, iconName: contact.iconName, iconColor: contact.iconColor);
  }

  Future<void> _pickContact(AppController state) async {
    final options = [
      ...state.loanContacts.where((contact) => !contact.archived).map(
            (contact) => SelectionOption(id: contact.id, title: contact.name, subtitle: contact.phone.isEmpty ? 'Saved person' : contact.phone, iconName: contact.iconName, iconColor: contact.iconColor),
          ),
      const SelectionOption(id: '__new__', title: 'Add new person', subtitle: 'Create while saving', iconName: 'favorite', iconColor: '#FBC879'),
    ];
    final selected = await showAppleWheelSelectionSheet(context, title: 'Choose a person', options: options, selectedId: contactId);
    if (selected != null && mounted) setState(() => contactId = selected);
  }

  Future<void> _save() async {
    if (busy) return;
    final state = context.read<AppController>();
    final principal = double.tryParse(amount.text.trim()) ?? 0;
    final annualRate = interestType == LoanInterestType.none ? 0.0 : double.tryParse(rate.text.trim()) ?? 0;
    if (!principal.isFinite || principal <= 0) return showSnack(context, 'Enter a valid amount.');
    if (!annualRate.isFinite || annualRate < 0 || annualRate > 1000) return showSnack(context, 'Enter a valid annual rate.');
    if (dueDate != null && dueDate!.isBefore(startDate)) return showSnack(context, 'Due date cannot be before the start date.');
    final movementAccountId = accountId;
    final recordDisbursal = !editing &&
        state.loanRecordTransactionsByDefault &&
        movementAccountId != null &&
        movementAccountId.isNotEmpty;
    if (!editing && state.loanRecordTransactionsByDefault &&
        (movementAccountId == null || movementAccountId.isEmpty)) {
      return showSnack(context, 'Select an account.');
    }
    setState(() => busy = true);
    try {
      var selectedContactId = contactId;
      if (selectedContactId == '__new__') {
        final name = newPerson.text.trim();
        if (name.isEmpty) throw StateError('Enter a person name.');
        final now = DateTime.now();
        final contact = LoanContact(id: _uuid.v4(), name: name, createdOn: now, updatedOn: now);
        await state.saveLoanContact(contact);
        selectedContactId = contact.id;
      }
      if (selectedContactId == null || selectedContactId.isEmpty) throw StateError('Select a person.');
      final now = DateTime.now();
      final old = widget.loan;
      final value = Loan(
        id: old?.id ?? _uuid.v4(),
        contactId: selectedContactId,
        direction: direction,
        principal: roundLoanMoney(principal),
        interestType: interestType,
        interestRate: annualRate,
        interestPeriod: interestPeriod,
        startDate: DateTime(startDate.year, startDate.month, startDate.day, startDate.hour, startDate.minute),
        dueDate: dueDate == null ? null : DateTime(dueDate!.year, dueDate!.month, dueDate!.day, dueDate!.hour, dueDate!.minute),
        // The plan/installment editor was removed from this popup. Preserve an
        // existing value when editing older records instead of silently erasing it.
        installmentCount: old?.installmentCount,
        interestAccrualStop: old?.interestAccrualStop ?? LoanAccrualStop.settled,
        note: note.text.trim(),
        status: old?.status ?? LoanStatus.active,
        closedOn: old?.closedOn,
        disbursalTransactionId: old?.disbursalTransactionId,
        createdOn: old?.createdOn ?? now,
        updatedOn: now,
      );
      await state.saveLoan(
        value,
        recordDisbursal: recordDisbursal,
        accountId: movementAccountId,
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) showSnack(context, error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppController>();
    final contactOption = _contactOption(state);
    final content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(editing ? 'Edit loan' : 'New loan', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900))),
              IconButton(onPressed: busy ? null : () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
            ],
          ),
          const SizedBox(height: 10),
          SleekPillSelector<LoanDirection>(
            options: const [
              SleekPillOption(value: LoanDirection.lent, label: 'I gave', icon: Icons.south_west_rounded),
              SleekPillOption(value: LoanDirection.borrowed, label: 'I took', icon: Icons.north_east_rounded),
            ],
            selected: direction,
            onChanged: (value) => setState(() => direction = value),
          ),
          const SizedBox(height: 6),
          Text(direction == LoanDirection.lent ? 'They owe you this amount.' : 'You owe them this amount.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: kSleekMuted, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          AppleSelectionField(label: 'Person', option: contactOption, onTap: () => _pickContact(state)),
          if (contactId == '__new__') ...[
            const SizedBox(height: 10),
            TextField(contextMenuBuilder: yutakaTextFieldContextMenu, enableInteractiveSelection: true, 
              onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
              controller: newPerson, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Person name', prefixIcon: Icon(Icons.person_add_rounded))),
          ],
          const SizedBox(height: 12),
          TextField(contextMenuBuilder: yutakaTextFieldContextMenu, enableInteractiveSelection: true, 
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            controller: amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Amount', prefixText: state.currencyPosition == CurrencyPosition.prefix ? state.currencySymbol : null, suffixText: state.currencyPosition == CurrencyPosition.suffix ? state.currencySymbol : null),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          if ((!editing && state.loanRecordTransactionsByDefault) ||
              (editing && widget.loan?.disbursalTransactionId != null)) ...[
            const SizedBox(height: 12),
            AppleSelectionField(
              label: direction == LoanDirection.lent ? 'Give from account' : 'Receive into account',
              option: state.accountOf(accountId ?? '') == null
                  ? null
                  : optionFromAccount(state.accountOf(accountId ?? '')!, state),
              onTap: () async {
                final selected = await showAppleWheelSelectionSheet(
                  context,
                  title: direction == LoanDirection.lent
                      ? 'Choose the account to give from'
                      : 'Choose the account to receive into',
                  options: state.accounts.map((item) => optionFromAccount(item, state)).toList(),
                  selectedId: accountId,
                );
                if (selected != null && mounted) setState(() => accountId = selected);
              },
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () async {
              FocusManager.instance.primaryFocus?.unfocus();
              final selection = await showLoanStartDateTimeConfiguration(
                context,
                start: startDate,
              );
              if (!mounted || selection == null) return;
              setState(() => startDate = selection.start);
            },
            child: _ConfigurationButtonLabel(
              icon: Icons.event_rounded,
              title: 'Time • Date',
              summary: '${DateFormat('MMM d, yyyy').format(startDate)} • ${DateFormat('h:mm a').format(startDate)}',
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              FocusManager.instance.primaryFocus?.unfocus();
              final selection = await showLoanInterestConfiguration(
                context,
                type: interestType,
                period: interestPeriod,
                rate: double.tryParse(rate.text.trim()) ?? 0,
              );
              if (!mounted || selection == null) return;
              setState(() {
                interestType = selection.type;
                interestPeriod = selection.period;
                rate.text = selection.rate <= 0
                    ? ''
                    : (selection.rate == selection.rate.roundToDouble()
                        ? selection.rate.toStringAsFixed(0)
                        : selection.rate.toStringAsFixed(2));
              });
            },
            icon: const Icon(Icons.percent_rounded),
            label: const Text('Interest'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () async {
              FocusManager.instance.primaryFocus?.unfocus();
              final selection = await showLoanDueDateTimeConfiguration(
                context,
                start: startDate,
                dueDate: dueDate,
              );
              if (!mounted || selection == null) return;
              setState(() => dueDate = selection.dueDate);
            },
            child: _ConfigurationButtonLabel(
              icon: Icons.event_available_rounded,
              title: 'Due date',
              summary: dueDate == null
                  ? 'Off'
                  : '${DateFormat('MMM d, yyyy').format(dueDate!)} • ${DateFormat('h:mm a').format(dueDate!)}',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            contextMenuBuilder: yutakaTextFieldContextMenu,
            enableInteractiveSelection: true,
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            controller: note, minLines: 1, maxLines: 3, decoration: const InputDecoration(labelText: 'Note (optional)')),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: busy ? null : () => Navigator.pop(context), child: const Text('Cancel'))),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: FilledButton(onPressed: busy ? null : _save, child: Text(busy ? 'Saving...' : 'Save loan'))),
            ],
          ),
        ],
      );

    return YutakaPopupContent(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
      child: content,
    );
  }
}

Future<void> showLoanPaymentSheet(BuildContext context, {required Loan loan, double? initialAmount}) {
  return showYutakaPopup<void>(
    context,
    maxWidth: 560,
    maxHeight: 700,
    barrierDismissible: false,
    child: _LoanPaymentSheet(loan: loan, initialAmount: initialAmount),
  );
}

class _LoanPaymentSheet extends StatefulWidget {
  const _LoanPaymentSheet({required this.loan, this.initialAmount});
  final Loan loan;
  final double? initialAmount;

  @override
  State<_LoanPaymentSheet> createState() => _LoanPaymentSheetState();
}

class _LoanPaymentSheetState extends State<_LoanPaymentSheet> {
  final amount = TextEditingController();
  final note = TextEditingController();
  DateTime paidOn = DateTime.now();
  String? accountId;
  bool recordInAccount = false;
  bool defaultsLoaded = false;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    final initialAmount = widget.initialAmount;
    if (initialAmount != null && initialAmount > 0) {
      amount.text = roundLoanMoney(initialAmount).toStringAsFixed(2);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (defaultsLoaded) return;
    final state = context.read<AppController>();
    accountId ??= state.defaultAccountId ?? state.accounts.firstOrNull?.id;
    recordInAccount = state.loanRecordTransactionsByDefault;
    defaultsLoaded = true;
  }

  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  void _fill(double value) {
    amount.text = roundLoanMoney(loanNonNegative(value)).toStringAsFixed(2);
    setState(() {});
  }

  Future<void> _save() async {
    if (busy) return;
    final state = context.read<AppController>();
    final value = double.tryParse(amount.text.trim()) ?? 0;
    if (!value.isFinite || value <= 0) return showSnack(context, 'Enter a valid payment amount.');
    if (recordInAccount && (accountId == null || accountId!.isEmpty)) return showSnack(context, 'Select an account.');
    setState(() => busy = true);
    try {
      final now = DateTime.now();
      final payment = LoanPayment(
        id: _uuid.v4(),
        loanId: widget.loan.id,
        amount: roundLoanMoney(value),
        interestComponent: 0,
        principalComponent: roundLoanMoney(value),
        paidOn: paidOn,
        note: note.text.trim(),
        createdOn: now,
        updatedOn: now,
      );
      await state.addLoanPayment(payment, recordInAccount: recordInAccount, accountId: accountId);
      if (mounted) {
        final remaining = loanNonNegative(state.computationFor(widget.loan.id).outstanding);
        showSnack(context, remaining <= 0.005 ? 'Payment recorded · settled.' : 'Payment recorded · ${state.format(remaining)} left.');
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) showSnack(context, error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppController>();
    final computation = state.computationFor(widget.loan.id, at: paidOn);
    final remaining = loanNonNegative(computation.outstanding);
    final value = double.tryParse(amount.text) ?? 0;
    final split = allocateLoanPayment(widget.loan, state.paymentsForLoan(widget.loan.id), value, paidOn);
    final account = state.accountOf(accountId ?? '');
    final content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Record payment', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900))),
              IconButton(onPressed: busy ? null : () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
            ],
          ),
          const SizedBox(height: 8),
          Text('Remaining ${state.format(remaining)}', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: kSleekAccent, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          TextField(contextMenuBuilder: yutakaTextFieldContextMenu, enableInteractiveSelection: true, 
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            controller: amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: 'Payment amount', suffixText: state.currencyPosition == CurrencyPosition.suffix ? state.currencySymbol : null),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(label: const Text('Full'), onPressed: () => _fill(remaining)),
              ActionChip(label: const Text('Half'), onPressed: () => _fill(remaining / 2)),
              if (computation.emiAmount != null) ActionChip(label: const Text('Monthly'), onPressed: () => _fill(computation.emiAmount!)),
              ActionChip(label: const Text('Round up'), onPressed: () => _fill((remaining / 100).ceil() * 100)),
            ],
          ),
          if (value > 0) ...[
            const SizedBox(height: 12),
            ExpressiveCard(
              padding: const EdgeInsets.all(12),
              child: Text(
                '${state.format(split.interest)} interest · ${state.format(split.principal)} principal\nRemaining after this: ${state.format(loanNonNegative(remaining - value))}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
          if (value > remaining + 0.005) ...[
            const SizedBox(height: 8),
            Text(
              'This overpays by ${state.format(value - remaining)}.',
              style: const TextStyle(color: kSleekWarning, fontWeight: FontWeight.w800),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final selected = await pickDate(context, paidOn);
              if (selected != null && mounted) {
                setState(() => paidOn = DateTime(
                      selected.year,
                      selected.month,
                      selected.day,
                      paidOn.hour,
                      paidOn.minute,
                    ));
              }
            },
            icon: const Icon(Icons.event_rounded),
            label: Text(DateFormat('MMM d, yyyy').format(paidOn)),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final selected = await pickTime(context, TimeOfDay.fromDateTime(paidOn));
              if (selected != null && mounted) {
                setState(() => paidOn = DateTime(
                      paidOn.year,
                      paidOn.month,
                      paidOn.day,
                      selected.hour,
                      selected.minute,
                    ));
              }
            },
            icon: const Icon(Icons.schedule_rounded),
            label: Text('Time · ${DateFormat('h:mm a').format(paidOn)}'),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: recordInAccount,
            onChanged: (value) => setState(() => recordInAccount = value),
            title: const Text('Record this in an account', style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: const Text('Updates the balance but stays outside reports.'),
          ),
          if (recordInAccount)
            AppleSelectionField(
              label: 'Account',
              option: account == null ? null : optionFromAccount(account, state),
              onTap: () async {
                final selected = await showAppleWheelSelectionSheet(
                  context,
                  title: 'Choose an account',
                  options: state.accounts.map((item) => optionFromAccount(item, state)).toList(),
                  selectedId: accountId,
                );
                if (selected != null && mounted) setState(() => accountId = selected);
              },
            ),
          const SizedBox(height: 12),
          TextField(
            contextMenuBuilder: yutakaTextFieldContextMenu,
            enableInteractiveSelection: true,
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            controller: note, minLines: 1, maxLines: 3, decoration: const InputDecoration(labelText: 'Note (optional)')),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: busy ? null : () => Navigator.pop(context), child: const Text('Cancel'))),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: FilledButton(onPressed: busy ? null : _save, child: Text(busy ? 'Saving...' : 'Save payment'))),
            ],
          ),
        ],
      );

    return YutakaPopupContent(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
      child: content,
    );
  }
}

Future<void> showLoanPreferencesSheet(BuildContext context) {
  return showYutakaPopup<void>(context, maxWidth: 540, maxHeight: 520, child: const _LoanPreferencesSheet());
}

class _LoanPreferencesSheet extends StatelessWidget {
  const _LoanPreferencesSheet();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppController>();
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Loan preferences', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900))),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: state.loanRecordTransactionsByDefault,
            onChanged: (value) => state.setLoanPreferences(recordTransactions: value),
            title: const Text('Record account movements by default', style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: const Text('These movements never count as income or expenses.'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: state.loanTransactionsVisibleInTransactionList,
            onChanged: (value) => state.setLoanPreferences(showTransactionsInTransactionList: value),
            title: const Text('Show loan transactions in Transaction', style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: const Text('Turn this off to hide loan-linked movements from the main Transaction list.'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: state.loanRemindersEnabled,
            onChanged: (value) => state.setLoanPreferences(reminders: value),
            title: const Text('Due-date reminders', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: state.loanShowWrittenOff,
            onChanged: (value) => state.setLoanPreferences(showWrittenOff: value),
            title: const Text('Show written-off records', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 10),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
        ],
      ),
    );
  }
}
