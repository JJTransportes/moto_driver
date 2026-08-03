abstract class UsageTermsEvent {
  const UsageTermsEvent();
}

class CheckStatus extends UsageTermsEvent {
  const CheckStatus();
}

class LoadTerms extends UsageTermsEvent {
  const LoadTerms();
}

class AcceptTerms extends UsageTermsEvent {
  const AcceptTerms();
}

class DeclineTerms extends UsageTermsEvent {
  const DeclineTerms();
}
