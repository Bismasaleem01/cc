import 'package:flutter/material.dart';
import '../constants/app_theme.dart';
import '../models/bill.dart';
import '../services/billing_service.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  List<Bill> _bills = [];
  bool _isLoading = true;
  int? _payingId;

  @override
  void initState() {
    super.initState();
    _loadBills();
  }

  Future<void> _loadBills() async {
    final bills = await BillingService.fetchBills();
    if (!mounted) return;
    setState(() {
      _bills = bills;
      _isLoading = false;
    });
  }

  Future<void> _pay(Bill bill) async {
    final confirmed = await _showPaymentSheet(bill);
    if (confirmed != true) return;

    setState(() => _payingId = bill.id);
    final error = await BillingService.payBill(bill.id);
    if (!mounted) return;
    setState(() => _payingId = null);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error ?? 'Payment successful.')));
    _loadBills();
  }

  Future<bool?> _showPaymentSheet(Bill bill) {
    final cardController = TextEditingController();
    final nameController = TextEditingController();
    final expiryController = TextEditingController();
    final cvvController = TextEditingController();

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 18,
            right: 18,
            top: 18,
            bottom: MediaQuery.of(context).viewInsets.bottom + 18,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryDark,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'E-Bill Summary',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        bill.description,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Invoice #${bill.id} • Appointment #${bill.appointmentId}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '\$${bill.amount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Cardholder name',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: cardController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Card number',
                    prefixIcon: Icon(Icons.credit_card),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: expiryController,
                        keyboardType: TextInputType.datetime,
                        decoration: const InputDecoration(labelText: 'MM/YY'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: cvvController,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'CVV'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (nameController.text.trim().isEmpty ||
                          cardController.text.trim().length < 12 ||
                          expiryController.text.trim().isEmpty ||
                          cvvController.text.trim().length < 3) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter valid card details.'),
                          ),
                        );
                        return;
                      }
                      Navigator.pop(context, true);
                    },
                    icon: const Icon(Icons.lock),
                    label: Text('Pay \$${bill.amount} Securely'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime value) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[value.month - 1]} ${value.day}, ${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    final unpaidTotal = _bills
        .where((bill) => bill.status == 'unpaid')
        .fold<int>(0, (sum, bill) => sum + bill.amount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Billing'),
        actions: [
          IconButton(onPressed: _loadBills, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadBills,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: unpaidTotal > 0
                          ? Colors.red.shade50
                          : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: unpaidTotal > 0
                            ? Colors.red.shade100
                            : Colors.green.shade100,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          unpaidTotal > 0
                              ? Icons.warning_amber
                              : Icons.verified,
                          color: unpaidTotal > 0
                              ? AppTheme.danger
                              : AppTheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            unpaidTotal > 0
                                ? 'Pending balance: \$$unpaidTotal. Please pay before booking another appointment.'
                                : 'No pending balance.',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_bills.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 80),
                        child: Text('No billing history yet.'),
                      ),
                    ),
                  ..._bills.map((bill) {
                    final isPaid = bill.status == 'paid';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isPaid
                              ? Colors.green.shade50
                              : Colors.orange.shade50,
                          child: Icon(
                            isPaid ? Icons.receipt_long : Icons.payments,
                            color: isPaid ? AppTheme.primary : AppTheme.warning,
                          ),
                        ),
                        title: Text(
                          bill.description,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Invoice #${bill.id} • Appointment #${bill.appointmentId}\n${_formatDate(bill.createdAt)} • ${isPaid ? 'Paid' : 'Unpaid'}',
                        ),
                        isThreeLine: true,
                        trailing: isPaid
                            ? Text(
                                '\$${bill.amount}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : ElevatedButton(
                                onPressed: _payingId == bill.id
                                    ? null
                                    : () => _pay(bill),
                                child: _payingId == bill.id
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text('Pay \$${bill.amount}'),
                              ),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}
