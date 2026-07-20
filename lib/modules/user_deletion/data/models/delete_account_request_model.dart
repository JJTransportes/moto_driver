class DeleteAccountRequestModel {
  final String password;

  const DeleteAccountRequestModel({required this.password});

  Map<String, dynamic> toJson() => {
        'password': password,
      };
}
