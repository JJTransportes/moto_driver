// =====================================================================
// Formulários — pacote 5 (Cobalto Líquido)
// Copiar para lib/design_system/widgets/ e exportar em design_system.dart:
//   export 'widgets/moto_form.dart';
//
//   TextFormField(
//     keyboardType: TextInputType.number,
//     inputFormatters: [MotoMasks.cpf],
//     validator: MotoValidators.all([MotoValidators.required, MotoValidators.cpf]),
//     autovalidateMode: AutovalidateMode.onUserInteraction,
//   )
//   MotoSelectField<String>(label: 'Órgão', options: [...], value: v, onChanged: ...)
//   MotoDateField(label: 'Data de nascimento', controller: nasc)
//   MotoPasswordRules(controller: senha) · MotoStrengthMeter(controller: senha)
//   MotoStepper(steps: ['Seus dados', 'Acesso', 'Revisão'], current: etapa)
//
// Mesmas regras e mensagens do web/formularios.js.
// =====================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../moto_palette.dart';
import '../moto_tokens.dart';
import 'moto_glass.dart';

// ---------------------------------------------------------------- MÁSCARAS
class _MaskFormatter extends TextInputFormatter {
  _MaskFormatter(this.format);
  final String Function(String digits) format;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = format(newValue.text);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

String _digits(String v) => v.replaceAll(RegExp(r'\D'), '');

String _pattern(String d, String mask) {
  final b = StringBuffer();
  var i = 0;
  for (final c in mask.split('')) {
    if (i >= d.length) break;
    if (c == '#') {
      b.write(d[i++]);
    } else {
      b.write(c);
    }
  }
  return b.toString();
}

abstract final class MotoMasks {
  static final cpf = _MaskFormatter(
    (v) => _pattern(_digits(v), '###.###.###-##'),
  );
  static final data = _MaskFormatter((v) => _pattern(_digits(v), '##/##/####'));
  static final cep = _MaskFormatter((v) => _pattern(_digits(v), '#####-###'));
  static final cnh = _MaskFormatter((v) {
    final d = _digits(v);
    return d.length > 11 ? d.substring(0, 11) : d;
  });
  static final tel = _MaskFormatter((v) {
    final d = _digits(v);
    return _pattern(d, d.length <= 10 ? '(##) ####-####' : '(##) #####-####');
  });
}

// ---------------------------------------------------------------- VALIDADORES
typedef MotoValidator = String? Function(String? value);

abstract final class MotoValidators {
  /// Junta vários: devolve a 1ª mensagem de erro.
  static MotoValidator all(List<MotoValidator> list) => (v) {
    for (final f in list) {
      final r = f(v);
      if (r != null) return r;
    }
    return null;
  };

  static String? required(String? v) =>
      (v ?? '').trim().isEmpty ? 'Campo obrigatório.' : null;

  static MotoValidator min(int n, [String? msg]) =>
      (v) => (v ?? '').trim().isEmpty || v!.trim().length >= n
      ? null
      : (msg ?? 'Use pelo menos $n caracteres.');

  static String? email(String? v) {
    if ((v ?? '').isEmpty) return null;
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(v!.trim())
        ? null
        : 'E-mail incompleto. Ex.: nome@jacarei.sp.gov.br';
  }

  static bool cpfOk(String v) {
    final d = _digits(v);
    if (d.length != 11 || RegExp(r'^(\d)\1{10}$').hasMatch(d)) return false;
    int dv(int len) {
      var s = 0;
      for (var i = 0; i < len; i++) {
        s += int.parse(d[i]) * (len + 1 - i);
      }
      final r = (s * 10) % 11;
      return r == 10 ? 0 : r;
    }

    return dv(9) == int.parse(d[9]) && dv(10) == int.parse(d[10]);
  }

  static String? cpf(String? v) {
    final d = _digits(v ?? '');
    if (d.isEmpty) return null;
    if (d.length < 11) return 'Faltam ${11 - d.length} dígitos.';
    return cpfOk(d) ? null : 'Esse CPF não existe. Confira os números.';
  }

  static String? cnh(String? v) {
    final d = _digits(v ?? '');
    if (d.isEmpty) return null;
    return d.length == 11
        ? null
        : 'A CNH tem 11 dígitos (faltam ${11 - d.length}).';
  }

  static String? tel(String? v) {
    final d = _digits(v ?? '');
    if (d.isEmpty) return null;
    return d.length >= 10 ? null : 'Telefone incompleto: DDD + número.';
  }

  /// DD/MM/AAAA → DateTime (null se inválida).
  static DateTime? parseData(String v) {
    final m = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(v);
    if (m == null) return null;
    final d = int.parse(m[1]!), mo = int.parse(m[2]!), y = int.parse(m[3]!);
    final dt = DateTime(y, mo, d);
    return dt.day == d && dt.month == mo && dt.year == y ? dt : null;
  }

  static String? data(String? v) {
    if ((v ?? '').isEmpty) return null;
    return parseData(v!) == null ? 'Data inválida. Use DD/MM/AAAA.' : null;
  }

  static String? maior16(String? v) {
    final dt = parseData(v ?? '');
    if (dt == null) return null;
    final now = DateTime.now();
    final limite = DateTime(now.year - 16, now.month, now.day);
    return dt.isAfter(limite) ? 'É preciso ter 16 anos ou mais.' : null;
  }

  /// Confirmar e-mail / senha. `other` lê o valor atual do outro campo.
  static MotoValidator match(
    String Function() other, {
    String msg = 'Não bate com o campo anterior.',
  }) =>
      (v) => (v ?? '').isEmpty || v == other() ? null : msg;

  static String? senha(String? v) =>
      MotoPasswordRule.values.every((r) => r.test(v ?? ''))
      ? null
      : 'A senha ainda não cumpre todos os requisitos.';
}

// ---------------------------------------------------------------- SENHA
enum MotoPasswordRule {
  len('Entre 8 e 72 caracteres'),
  caseMix('1 maiúscula e 1 minúscula'),
  num('Pelo menos 1 número'),
  special('1 caractere especial (! @ # \$ %)');

  const MotoPasswordRule(this.label);
  final String label;

  bool test(String v) => switch (this) {
    len => v.length >= 8 && v.length <= 72,
    caseMix => RegExp('[a-z]').hasMatch(v) && RegExp('[A-Z]').hasMatch(v),
    num => RegExp(r'\d').hasMatch(v),
    special => RegExp(r'[^A-Za-z0-9]').hasMatch(v),
  };

  /// 0–4, igual ao medidor do web.
  static int level(String v) =>
      v.isEmpty ? 0 : values.where((r) => r.test(v)).length.clamp(1, 4);
}

/// Lista de requisitos que marca enquanto digita.
class MotoPasswordRules extends StatelessWidget {
  const MotoPasswordRules({super.key, required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final p = context.moto;
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, value, _) => Container(
        padding: const EdgeInsets.all(MotoSpace.s4),
        decoration: BoxDecoration(
          color: p.bgSunken,
          borderRadius: MotoRadius.brMd,
          border: Border.all(color: p.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final r in MotoPasswordRule.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: _RuleRow(label: r.label, ok: r.test(value.text)),
              ),
          ],
        ),
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.label, required this.ok});
  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final p = context.moto;
    return Row(
      children: [
        AnimatedContainer(
          duration: MotoMotion.base,
          curve: MotoMotion.spring,
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ok ? p.signal : Colors.transparent,
            border: Border.all(
              color: ok ? p.signal : p.borderStrong,
              width: 1.5,
            ),
          ),
          child: AnimatedScale(
            scale: ok ? 1 : 0,
            duration: MotoMotion.base,
            curve: MotoMotion.spring,
            child: Icon(Icons.check_rounded, size: 12, color: p.textOnSignal),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AnimatedDefaultTextStyle(
            duration: MotoMotion.fast,
            style: TextStyle(
              fontFamily: MotoFont.ui,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: ok ? p.textPrimary : p.textSecondary,
            ),
            child: Text(label),
          ),
        ),
      ],
    );
  }
}

/// Medidor de força em 4 barras: Fraca · Média · Boa · Forte.
class MotoStrengthMeter extends StatelessWidget {
  const MotoStrengthMeter({
    super.key,
    required this.controller,
    this.label = 'Força da senha',
  });
  final TextEditingController controller;
  final String label;

  static const _names = ['—', 'Fraca', 'Média', 'Boa', 'Forte'];

  @override
  Widget build(BuildContext context) {
    final p = context.moto;
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, value, _) {
        final lv = MotoPasswordRule.level(value.text);
        final color = [
          p.borderDefault,
          p.danger,
          p.warning,
          p.accentBright,
          p.signal,
        ][lv];
        final textColor = [
          p.textTertiary,
          p.danger,
          p.warning,
          p.accent,
          p.signalText,
        ][lv];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                for (var i = 0; i < 4; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: AnimatedContainer(
                      duration: MotoMotion.base,
                      curve: MotoMotion.easeOut,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i < lv ? color : p.borderSubtle,
                        borderRadius: MotoRadius.brPill,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: MotoFont.ui,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: p.textTertiary,
                    ),
                  ),
                ),
                Text(
                  _names[lv],
                  style: TextStyle(
                    fontFamily: MotoFont.ui,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------- SELETOR
class MotoOption<T> {
  const MotoOption(this.value, this.label, {this.caption, this.icon});
  final T value;
  final String label;
  final String? caption;
  final IconData? icon;
}

/// Campo que abre uma lista de vidro com busca (bottom sheet).
/// Valida como qualquer FormField: `validator: (v) => v == null ? 'Escolha um órgão.' : null`.
class MotoSelectField<T> extends FormField<T> {
  MotoSelectField({
    super.key,
    required String label,
    required List<MotoOption<T>> options,
    T? value,
    ValueChanged<T>? onChanged,
    String hint = 'Selecione',
    IconData? icon,
    bool searchable = true,
    String? errorText,
    super.validator,
  }) : super(
         initialValue: value,
         autovalidateMode: AutovalidateMode.onUserInteraction,
         builder: (state) {
           final ctx = state.context;
           MotoOption<T>? sel;
           for (final o in options) {
             if (o.value == state.value) sel = o;
           }
           return InkWell(
             borderRadius: MotoRadius.brMd,
             onTap: () async {
               final picked = await showModalBottomSheet<T>(
                 context: ctx,
                 isScrollControlled: true,
                 backgroundColor: Colors.transparent,
                 builder: (_) => _SelectSheet<T>(
                   title: label,
                   options: options,
                   selected: state.value,
                   searchable: searchable,
                 ),
               );
               if (picked != null) {
                 state.didChange(picked);
                 onChanged?.call(picked);
               }
             },
             child: InputDecorator(
               isEmpty: sel == null,
               decoration: InputDecoration(
                 labelText: label,
                 hintText: hint,
                 errorText: errorText ?? state.errorText,
                 prefixIcon: icon == null ? null : Icon(icon),
                 suffixIcon: const Icon(Icons.expand_more_rounded),
               ),
               child: sel == null
                   ? null
                   : Text(
                       sel.label,
                       maxLines: 1,
                       overflow: TextOverflow.ellipsis,
                     ),
             ),
           );
         },
       );
}

class _SelectSheet<T> extends StatefulWidget {
  const _SelectSheet({
    required this.title,
    required this.options,
    required this.selected,
    required this.searchable,
  });
  final String title;
  final List<MotoOption<T>> options;
  final T? selected;
  final bool searchable;

  @override
  State<_SelectSheet<T>> createState() => _SelectSheetState<T>();
}

class _SelectSheetState<T> extends State<_SelectSheet<T>> {
  String q = '';

  // "saude" acha "Saúde"
  static String _fold(String s) {
    const a = 'áàâãäéèêëíìîïóòôõöúùûüç', b = 'aaaaaeeeeiiiiooooouuuuc';
    final low = s.toLowerCase();
    final out = StringBuffer();
    for (final c in low.split('')) {
      final i = a.indexOf(c);
      out.write(i < 0 ? c : b[i]);
    }
    return out.toString();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.moto;
    final list = widget.options
        .where((o) => _fold('${o.label} ${o.caption ?? ''}').contains(_fold(q)))
        .toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: MotoGlass(
        level: GlassLevel.sheet,
        borderRadius: MotoRadius.brSheet,
        padding: const EdgeInsets.fromLTRB(
          MotoSpace.gutter,
          12,
          MotoSpace.gutter,
          MotoSpace.s6,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: p.borderStrong,
                    borderRadius: MotoRadius.brPill,
                  ),
                ),
              ),
              const SizedBox(height: MotoSpace.s4),
              Text(
                widget.title,
                style: TextStyle(
                  fontFamily: MotoFont.display,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: p.textPrimary,
                ),
              ),
              if (widget.searchable) ...[
                const SizedBox(height: MotoSpace.s3),
                TextField(
                  autofocus: false,
                  onChanged: (v) => setState(() => q = v),
                  decoration: InputDecoration(
                    hintText: 'Buscar ${widget.title.toLowerCase()}',
                    prefixIcon: const Icon(Icons.search_rounded),
                  ),
                ),
              ],
              const SizedBox(height: MotoSpace.s2),
              Flexible(
                child: list.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(MotoSpace.s6),
                        child: Text(
                          'Nada encontrado para "$q".',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: p.textTertiary),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: list.length,
                        itemBuilder: (context, i) {
                          final o = list[i];
                          final on = o.value == widget.selected;
                          return Material(
                            color: Colors.transparent,
                            child: ListTile(
                              shape: const RoundedRectangleBorder(
                                borderRadius: MotoRadius.brSm,
                              ),
                              selected: on,
                              selectedTileColor: p.accentSoft,
                              leading: o.icon == null
                                  ? null
                                  : Icon(o.icon, color: p.accent),
                              title: Text(
                                o.label,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: p.textPrimary,
                                ),
                              ),
                              subtitle: o.caption == null
                                  ? null
                                  : Text(o.caption!),
                              trailing: on
                                  ? Icon(Icons.check_rounded, color: p.accent)
                                  : null,
                              onTap: () => Navigator.pop(context, o.value),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- DATA
/// Digitar com máscara OU tocar no calendário. Formato DD/MM/AAAA.
class MotoDateField extends StatelessWidget {
  const MotoDateField({
    super.key,
    required this.label,
    required this.controller,
    this.validator,
    this.first,
    this.last,
    this.birthDate = false,
  });

  final String label;
  final TextEditingController controller;
  final MotoValidator? validator;
  final DateTime? first, last;

  /// true abre o calendário em anos (bom para nascimento).
  final bool birthDate;

  static String format(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final f = first ?? DateTime(1920), l = last ?? DateTime(now.year + 20);
    var initial =
        MotoValidators.parseData(controller.text) ??
        (birthDate ? DateTime(now.year - 30) : now);
    if (initial.isBefore(f)) initial = f;
    if (initial.isAfter(l)) initial = l;
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: f,
      lastDate: l,
      initialDatePickerMode: birthDate
          ? DatePickerMode.year
          : DatePickerMode.day,
      helpText: label,
      cancelText: 'Fechar',
      confirmText: 'Escolher',
    );
    if (d != null) controller.text = format(d);
  }

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    keyboardType: TextInputType.datetime,
    inputFormatters: [MotoMasks.data],
    autovalidateMode: AutovalidateMode.onUserInteraction,
    validator: validator ?? MotoValidators.data,
    decoration: InputDecoration(
      labelText: label,
      hintText: 'DD/MM/AAAA',
      prefixIcon: const Icon(Icons.calendar_today_rounded),
      suffixIcon: IconButton(
        tooltip: 'Abrir calendário',
        icon: const Icon(Icons.event_rounded),
        onPressed: () => _pick(context),
      ),
    ),
  );
}

// ---------------------------------------------------------------- ETAPAS
/// Barra de etapas: concluída (check) · atual (anel) · próxima.
class MotoStepper extends StatelessWidget {
  const MotoStepper({super.key, required this.steps, required this.current});
  final List<String> steps;
  final int current;

  @override
  Widget build(BuildContext context) {
    final p = context.moto;
    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: MotoMotion.slow,
                  curve: MotoMotion.easeOut,
                  height: 5,
                  decoration: BoxDecoration(
                    color: i <= current ? p.accent : p.borderSubtle,
                    borderRadius: MotoRadius.brPill,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    AnimatedContainer(
                      duration: MotoMotion.base,
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < current ? p.accent : p.bgRaised,
                        border: Border.all(
                          color: i == current
                              ? p.accentBright
                              : (i < current ? p.accent : p.borderDefault),
                          width: i == current ? 1.5 : 1,
                        ),
                      ),
                      child: i < current
                          ? Icon(
                              Icons.check_rounded,
                              size: 13,
                              color: p.textOnAccent,
                            )
                          : Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontFamily: MotoFont.display,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: i == current ? p.accent : p.textTertiary,
                              ),
                            ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        steps[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: MotoFont.ui,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: i <= current ? p.textPrimary : p.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
