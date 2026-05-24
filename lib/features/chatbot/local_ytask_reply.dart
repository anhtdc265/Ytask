/// Local replies for common YTask chatbot questions.
///
/// This file handles stable FAQ/help questions before the app falls back to
/// task-consultation logic. It intentionally keeps answers short and avoids
/// exposing implementation details to end users.
class LocalYTaskReplyService {
  const LocalYTaskReplyService._();

  static String? getReply(String userMessage) {
    final text = normalize(userMessage);

    if (text.isEmpty) {
      return null;
    }

    // Câu ra lệnh tạo task phải đi qua luồng AI tạo bản nháp + preview,
    // không được bị local FAQ chặn thành câu hướng dẫn.
    if (_looksLikeDirectCreateTaskCommand(text)) {
      return null;
    }

    if (_looksLikePersonalTaskConsultation(text) &&
        !_looksLikeHowToUseQuestion(text)) {
      return null;
    }

    for (final rule in _rules) {
      if (rule.matches(text)) {
        return rule.reply;
      }
    }

    return null;
  }

  static bool canReply(String userMessage) => getReply(userMessage) != null;

  /// Public so other local services can use the exact same normalization rules.
  static String normalize(String input) {
    var text = input.toLowerCase();

    text = text
        .replaceAll(RegExp(r'[àáạảãâầấậẩẫăằắặẳẵ]'), 'a')
        .replaceAll(RegExp(r'[èéẹẻẽêềếệểễ]'), 'e')
        .replaceAll(RegExp(r'[ìíịỉĩ]'), 'i')
        .replaceAll(RegExp(r'[òóọỏõôồốộổỗơờớợởỡ]'), 'o')
        .replaceAll(RegExp(r'[ùúụủũưừứựửữ]'), 'u')
        .replaceAll(RegExp(r'[ỳýỵỷỹ]'), 'y')
        .replaceAll('đ', 'd')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    text = ' $text ';

    final replacements = <RegExp, String>{
      RegExp(r'\b(hnay|hum nay|homnay|hn)\b'): ' hom nay ',
      RegExp(r'\b(mai)\b'): ' ngay mai ',
      RegExp(r'\b(cv)\b'): ' cong viec ',
      RegExp(r'\b(nv|nvu)\b'): ' nhiem vu ',
      RegExp(r'\b(tk|tsk)\b'): ' task ',
      RegExp(r'\b(dl|ddl|deadlinee|dealline|dead line)\b'): ' deadline ',
      RegExp(r'\b(pri|prio)\b'): ' priority ',
      RegExp(r'\b(han chot|thoi han|het han)\b'): ' deadline ',
      RegExp(r'\b(done|xong roi|da xong)\b'): ' hoan thanh ',
      RegExp(r'\b(cancel|canceled|cancelled)\b'): ' huy ',
      RegExp(r'\b(oke|okay|okela|okie|oki|ok)\b'): ' oke ',
      RegExp(r'\b(app nay|ung dung nay)\b'): ' ytask ',
      RegExp(r'\b(assistant|bot|tro ly)\b'): ' tro ly ',
    };

    for (final entry in replacements.entries) {
      text = text.replaceAll(entry.key, entry.value);
    }

    text = text.replaceAllMapped(
      RegExp(r'(.)\1{2,}'),
          (match) => '${match.group(1)}${match.group(1)}',
    );

    return text
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static final List<_LocalReplyRule> _rules = <_LocalReplyRule>[
    _LocalReplyRule(
      patterns: <String>[
        r'\bytask\b.*\b(la gi|dung de lam gi|de lam gi|co tac dung gi|co ich gi|giup duoc gi|co gi hay|tot khong|huu ich|co huu ich khong)\b',
        r'\bwhat is ytask\b',
        r'\bytask la ung dung gi\b',
      ],
      reply:
      'YTask là ứng dụng quản lý công việc cá nhân. App giúp bạn tạo nhiệm vụ, đặt thời gian, theo dõi tiến độ, xử lý việc quá hạn và sắp xếp công việc theo ưu tiên.',
    ),
    _LocalReplyRule(
      patterns: <String>[
        r'\b(ytask ai|tro ly ytask|tro ly ai|chatbot|tro ly)\b.*\b(la gi|dung de lam gi|lam duoc gi|ho tro gi|co tac dung gi|giup duoc gi)\b',
        r'\bwhat is ytask ai\b',
        r'\byou are ytask ai\b',
        r'\bwho are you\b',
        r'\bban la ai\b',
      ],
      reply:
      'Mình là trợ lý AI trong YTask. Mình có thể hướng dẫn cách dùng app, gợi ý sắp xếp công việc, xem deadline và tạo bản nháp nhiệm vụ từ câu chat tự nhiên để bạn xác nhận trước khi lưu.',
    ),
    _LocalReplyRule(
      patterns: <String>[
        r'\b(oke|cam on|thank|thanks|ok)\b',
        r'\bduoc roi\b',
      ],
      reply:
      'Oke nè. Bạn có thể hỏi mình về cách dùng YTask, kế hoạch hôm nay, task gần deadline, nhiệm vụ quá hạn hoặc thứ tự ưu tiên công việc.',
    ),
    _LocalReplyRule(
      patterns: <String>[
        r'\b(dashboard|trang chu|man hinh chinh)\b.*\b(la gi|dung de lam gi|co gi|o dau)\b',
        r'\b(xem|tim)\b.*\b(danh sach nhiem vu|lich|cong viec hom nay)\b.*\b(o dau|o man hinh nao)\b',
      ],
      reply:
      'Dashboard là màn hình chính của YTask. Tại đây bạn xem lịch, danh sách nhiệm vụ trong ngày và bấm nút dấu cộng (+) để tạo nhiệm vụ mới.',
    ),
    _LocalReplyRule(
      patterns: <String>[
        r'\b(lam sao|cach|huong dan|lam the nao|chi toi|chi minh)\b.*\b(tao|them)\b.*\b(nhiem vu|task|cong viec)\b.*\b(ai|ytask ai|tro ly|chatbot|ngon ngu tu nhien|cau chat)\b',
        r'\b(ai|ytask ai|tro ly|chatbot)\b.*\b(tao|them)\b.*\b(nhiem vu|task|cong viec)\b.*\b(nhu the nao|bang cach nao|duoc khong|co duoc khong)\b',
        r'\b(tao|them)\b.*\b(nhiem vu|task|cong viec)\b\s*(bang|voi)\s*\b(ai|ytask ai|tro ly|chatbot|ngon ngu tu nhien|cau chat)\b',
        r'\b(ngon ngu tu nhien|cau chat)\b.*\b(tao|them)\b.*\b(nhiem vu|task|cong viec)\b',
      ],
      reply:
      'Bạn có thể tạo nhiệm vụ bằng AI ngay trong màn Chatbot. Hãy gõ tự nhiên, ví dụ: “Tạo nhiệm vụ học Flutter lúc 8 giờ tối nay, ưu tiên cao, nhắc trước 15 phút”. AI sẽ tạo bản nháp để bạn kiểm tra; chỉ khi bạn bấm “Tạo nhiệm vụ” thì app mới lưu.',
    ),
    _LocalReplyRule(
      patterns: <String>[
        r'\b(lam sao|cach|huong dan|lam the nao|chi toi|chi minh)\b.*\b(tao|them)\b.*\b(nhiem vu|task|cong viec)\b',
        r'\b(tao|them)\b.*\b(nhiem vu|task|cong viec)\b.*\b(nhu the nao|o dau|bang cach nao|duoc khong)\b',
      ],
      reply:
      'Bạn có 2 cách tạo nhiệm vụ: bấm dấu cộng (+) ở Dashboard để nhập thủ công, hoặc gõ ngay trong Chatbot câu như “Tạo nhiệm vụ học Flutter lúc 8 giờ tối nay”. Với cách AI, app sẽ mở bản nháp để bạn xác nhận trước khi lưu.',
    ),
    _LocalReplyRule(
      patterns: <String>[
        r'\b(lam sao|cach|huong dan|lam the nao)\b.*\b(sua|chinh sua|cap nhat)\b.*\b(nhiem vu|task|cong viec)\b',
        r'\b(sua|chinh sua|cap nhat)\b.*\b(nhiem vu|task|cong viec)\b.*\b(nhu the nao|o dau|bang cach nao)\b',
      ],
      reply:
      'Bạn mở chi tiết nhiệm vụ, sau đó chỉnh các thông tin cần thay đổi như tiêu đề, thời gian, trạng thái, vị trí hoặc nhắc nhở.',
    ),
    _LocalReplyRule(
      patterns: <String>[
        r'\b(lam sao|cach|huong dan|lam the nao)\b.*\b(xoa|huy)\b.*\b(nhiem vu|task|cong viec)\b',
        r'\b(xoa|huy)\b.*\b(nhiem vu|task|cong viec)\b.*\b(nhu the nao|o dau|bang cach nao)\b',
      ],
      reply:
      'Bạn mở nhiệm vụ cần xử lý rồi chọn hủy hoặc xóa nếu màn hình có hỗ trợ. Trước khi xác nhận, nên kiểm tra lại để tránh thao tác nhầm.',
    ),
    _LocalReplyRule(
      patterns: <String>[
        r'\b(lam sao|cach|huong dan|lam the nao)\b.*\b(hoan thanh|complete|done)\b.*\b(nhiem vu|task|cong viec)\b',
        r'\b(danh dau|dat)\b.*\b(nhiem vu|task|cong viec)\b.*\b(hoan thanh|da xong)\b',
      ],
      reply:
      'Bạn mở chi tiết nhiệm vụ rồi dùng hành động “Hoàn thành”. Khi hoàn thành, nhiệm vụ sẽ chuyển sang trạng thái completed.',
    ),
    _LocalReplyRule(
      patterns: <String>[
        r'\bprogress\b.*\b(la gi|dung de lam gi|co tac dung gi|co gi)\b',
        r'\b(theo doi tien do|tien do cong viec)\b.*\b(o dau|nhu the nao|la gi)\b',
      ],
      reply:
      'Progress là màn hình theo dõi tiến độ công việc. Bạn có thể xem nhiệm vụ đang chờ, đang làm, đã hoàn thành hoặc đã hủy.',
    ),
    _LocalReplyRule(
      patterns: <String>[
        r'\b(profile|tai khoan|ca nhan)\b.*\b(la gi|dung de lam gi|co gi|o dau)\b',
        r'\b(thong tin ca nhan|tai khoan)\b.*\b(o dau|xem o dau|sua o dau)\b',
      ],
      reply:
      'Profile là màn hình tài khoản/cá nhân. Bạn có thể xem thông tin người dùng và các tùy chọn liên quan đến tài khoản.',
    ),
    _LocalReplyRule(
      patterns: <String>[
        r'\b(nhiem vu|task|cong viec)\b.*\bqua han\b.*\b(la gi|nghia la gi)\b',
        r'\bqua han\b.*\b(la gi|nghia la gi)\b',
      ],
      reply:
      'Nhiệm vụ quá hạn là nhiệm vụ đã qua thời gian kết thúc nhưng chưa được hoàn thành. Đây là việc nên xử lý sớm để tránh dồn việc.',
    ),
    _LocalReplyRule(
      patterns: <String>[
        r'\b(lam sao|cach|huong dan|lam the nao)\b.*\b(xem|tim|kiem tra)\b.*\b(nhiem vu|task|cong viec)\b.*\bqua han\b',
        r'\b(xem|tim|kiem tra)\b.*\b(nhiem vu|task|cong viec)\b.*\bqua han\b.*\b(o dau|nhu the nao)\b',
      ],
      reply:
      'Bạn có thể xem nhiệm vụ quá hạn ở Dashboard hoặc Progress. Nhiệm vụ quá hạn thường là việc đã qua thời gian kết thúc nhưng chưa hoàn thành.',
    ),
    _LocalReplyRule(
      patterns: <String>[
        r'\btrang thai\b.*\b(nhiem vu|task|cong viec)\b.*\b(la gi|gom nhung gi|co nhung gi)\b',
        r'\b(status)\b.*\b(la gi|gom nhung gi|co nhung gi)\b',
      ],
      reply:
      'YTask có các trạng thái chính: pending là đang chờ, inProgress là đang làm, completed là đã hoàn thành và cancelled là đã hủy.',
    ),
    _LocalReplyRule(
      patterns: <String>[
        r'\bpriority\b.*\b(la gi|dung de lam gi|co tac dung gi)\b',
        r'\bdo uu tien\b.*\b(la gi|dung de lam gi|co tac dung gi|gom nhung gi)\b',
        r'\b(thap|trung binh|cao)\b.*\b(priority|do uu tien)\b',
      ],
      reply:
      'Độ ưu tiên giúp bạn biết nhiệm vụ nào quan trọng hơn. YTask thường dùng 3 mức: Thấp, Trung bình và Cao.',
    ),
    _LocalReplyRule(
      patterns: <String>[
        r'\b(reminder|nhac nho)\b.*\b(la gi|dung de lam gi|co tac dung gi|nhu the nao)\b',
        r'\b(lam sao|cach|huong dan|lam the nao)\b.*\b(dat|them|tao)\b.*\b(nhac nho|reminder)\b',
      ],
      reply:
      'Nhắc nhở giúp bạn không quên nhiệm vụ. Khi tạo hoặc sửa nhiệm vụ, bạn có thể đặt nhắc trước thời gian bắt đầu hoặc trước deadline nếu cần.',
    ),
    _LocalReplyRule(
      patterns: <String>[
        r'\b(category|danh muc|nhan)\b.*\b(la gi|dung de lam gi|co tac dung gi)\b',
        r'\bnhan\b.*\b(nhiem vu|task|cong viec)\b.*\b(la gi|dung de lam gi)\b',
      ],
      reply:
      'Nhãn hoặc danh mục giúp bạn phân loại nhiệm vụ, ví dụ: Học tập, Công việc, Cá nhân. Nhờ vậy bạn dễ lọc và sắp xếp công việc hơn.',
    ),
    _LocalReplyRule(
      patterns: <String>[
        r'\b(location|vi tri)\b.*\b(la gi|dung de lam gi|co tac dung gi)\b',
        r'\bvi tri\b.*\b(nhiem vu|task|cong viec)\b.*\b(la gi|dung de lam gi)\b',
      ],
      reply:
      'Vị trí là thông tin nơi thực hiện nhiệm vụ, ví dụ: nhà, trường, công ty. Trường này giúp bạn ghi nhớ bối cảnh công việc rõ hơn.',
    ),
    _LocalReplyRule(
      patterns: <String>[
        r'\b(deadline|thoi gian ket thuc)\b.*\b(la gi|nghia la gi|dung de lam gi)\b',
      ],
      reply:
      'Deadline là thời điểm nhiệm vụ cần hoàn thành. Trong YTask, bạn có thể dùng thời gian kết thúc để biết việc nào sắp đến hạn hoặc đã quá hạn.',
    ),
    _LocalReplyRule(
      patterns: <String>[
        r'\b(thoi gian bat dau|start time)\b.*\b(la gi|dung de lam gi|nghia la gi)\b',
      ],
      reply:
      'Thời gian bắt đầu cho biết khi nào bạn dự định làm nhiệm vụ. Nó giúp YTask sắp xếp lịch và gợi ý thứ tự làm việc hợp lý hơn.',
    ),
    _LocalReplyRule(
      patterns: <String>[
        r'\b(eisenhower|quan trong khan cap|khan cap quan trong)\b.*\b(la gi|dung de lam gi|nhu the nao)\b',
      ],
      reply:
      'Ma trận quan trọng/khẩn cấp giúp chia việc thành 4 nhóm: làm ngay, lên lịch, xử lý sau hoặc bỏ qua. Trong YTask, có thể dựa vào priority và deadline để phân loại.',
    ),
    _LocalReplyRule(
      patterns: <String>[
        r'\b(time blocking|chia khung gio|chia lich)\b.*\b(la gi|dung de lam gi|nhu the nao)\b',
      ],
      reply:
      'Time blocking là cách chia ngày thành các khung giờ cho từng nhiệm vụ. Cách này giúp bạn tập trung hơn và tránh làm nhiều việc cùng lúc.',
    ),
    _LocalReplyRule(
      patterns: <String>[
        r'\b(checklist|chia nho nhiem vu|chia nho task)\b.*\b(la gi|dung de lam gi|nhu the nao)\b',
      ],
      reply:
      'Checklist giúp chia một nhiệm vụ lớn thành các bước nhỏ dễ làm hơn. Bạn nên bắt đầu bằng bước rõ nhất, ngắn nhất để giảm cảm giác ngại bắt đầu.',
    ),
    _LocalReplyRule(
      patterns: <String>[
        r'\b(dang nhap|login)\b.*\b(dung de lam gi|tai sao can|de lam gi)\b',
        r'\b(tai sao|vi sao)\b.*\b(can dang nhap|phai dang nhap)\b',
      ],
      reply:
      'Bạn cần đăng nhập để YTask lưu nhiệm vụ theo tài khoản riêng. Nhờ vậy dữ liệu của bạn không bị lẫn với người dùng khác.',
    ),
    _LocalReplyRule(
      patterns: <String>[
        r'\b(du lieu|nhiem vu|task)\b.*\b(luu o dau|duoc luu o dau|co rieng khong|co bi lan khong)\b',
      ],
      reply:
      'Dữ liệu nhiệm vụ được lưu theo tài khoản đăng nhập. Mỗi người dùng có danh sách công việc riêng và không bị lẫn với người khác.',
    ),
    _LocalReplyRule(
      patterns: <String>[
        r'\b(ai|tro ly|ban)\b.*\b(co tu tao|tu luu|tu ghi|tu them)\b.*\b(nhiem vu|task|cong viec)\b',
        r'\btao\b.*\b(nhiem vu|task|cong viec)\b.*\b(bang ai|tu ngon ngu tu nhien)\b.*\b(nhu the nao|duoc khong)\b',
      ],
      reply:
      'Trợ lý AI có thể tạo bản nháp nhiệm vụ từ câu chat tự nhiên, nhưng không tự lưu ngay. Bạn cần xem lại thông tin và bấm “Tạo nhiệm vụ” thì nhiệm vụ mới được lưu vào YTask.',
    ),
    _LocalReplyRule(
      patterns: <String>[
        r'\b(ai|tro ly|ban)\b.*\b(co doc|co xem|xem duoc|doc duoc)\b.*\b(nhiem vu|task|cong viec)\b',
        r'\bdu lieu\b.*\b(nhiem vu|task|cong viec)\b.*\b(cua toi|nguoi dung rieng)\b',
      ],
      reply:
      'Với câu hỏi tư vấn kế hoạch, YTask có thể dùng nhiệm vụ của tài khoản đang đăng nhập để gợi ý. Mình không tự bịa dữ liệu và không tự thay đổi nhiệm vụ nếu bạn chưa xác nhận.',
    ),
    _LocalReplyRule(
      patterns: <String>[
        r'\b(tai sao|vi sao)\b.*\b(tro ly|chatbot|ai)\b.*\b(tra loi cham|lau|mat thoi gian)\b',
        r'\b(tro ly|chatbot|ai)\b.*\b(cham|lau|loading lau)\b',
      ],
      reply:
      'Trợ lý có thể cần thêm chút thời gian khi câu hỏi liên quan đến nhiều nhiệm vụ. Bạn có thể hỏi ngắn gọn hơn để nhận phản hồi nhanh và rõ hơn.',
    ),
    _LocalReplyRule(
      patterns: <String>[
        r'\b(testcase|demo)\b.*\b(chatbot|ai|tro ly)\b.*\b(can gi|nen lam gi|hoi gi)\b',
        r'\b(chatbot|ai|tro ly)\b.*\b(demo|bao ve do an)\b.*\b(can gi|nen lam gi|hoi gi)\b',
      ],
      reply:
      'Khi demo, bạn nên hỏi các câu ngắn về cách dùng app, kế hoạch hôm nay, deadline, ưu tiên, trạng thái và danh mục nhiệm vụ.',
    ),
  ];

  static bool _looksLikeDirectCreateTaskCommand(String text) {
    if (_looksLikeHowToUseQuestion(text)) {
      return false;
    }

    final commandPatterns = <RegExp>[
      RegExp(r'\b(tao|them)\b.*\b(nhiem vu|task|cong viec)\b'),
      RegExp(r'\b(can tao|tao cho|them cho)\b.*\b(nhiem vu|task|cong viec)\b'),
      RegExp(r'\bnhac\b.*\b(toi|minh|em|tui|tao)\b'),
      RegExp(r'\b(len lich|dat lich|ghi nho giup toi|ghi nho giup minh|ghi nho cho toi)\b'),
      RegExp(
        r'\b(den hen|toi hen|sap den hen|hen)\b.*\b(hom nay|ngay mai|mai|toi nay|sang mai|chieu mai|toi mai|\d{1,2}\s*(h|gio|:))\b',
      ),
    ];

    return commandPatterns.any((pattern) => pattern.hasMatch(text));
  }

  static bool _looksLikeHowToUseQuestion(String text) {
    final helpWords = <RegExp>[
      RegExp(r'\b(lam sao|cach|huong dan|lam the nao|o dau|nhu the nao|bang cach nao|chi toi|chi minh)\b'),
      RegExp(r'\b(la gi|dung de lam gi|co tac dung gi|nghia la gi|co ich gi|giup duoc gi)\b'),
      RegExp(r'\b(duoc khong|co duoc khong|co the|co tao duoc|tao duoc|them duoc)\b'),
      RegExp(r'\b(bang|voi)\s*(ai|ytask ai|tro ly|chatbot|ngon ngu tu nhien|cau chat)\b'),
    ];

    return helpWords.any((pattern) => pattern.hasMatch(text));
  }

  static bool _looksLikePersonalTaskConsultation(String text) {
    final dynamicPatterns = <RegExp>[
      RegExp(r'\b(hom nay|ngay hom nay)\b.*\b(cong viec|nhiem vu|task|viec|ke hoach|lich|nen|can|co|con|lam gi|uu tien|deadline|qua han)\b'),
      RegExp(r'\b(cong viec|nhiem vu|task|viec|ke hoach|lich)\b.*\b(hom nay|ngay hom nay)\b'),
      RegExp(r'\b(task nao|nhiem vu nao|viec nao|cong viec nao)\b.*\b(gan deadline|deadline|qua han|uu tien|quan trong|lam truoc|gap|can xu ly)\b'),
      RegExp(r'\b(co task nao|co nhiem vu nao|co viec nao|co cong viec nao)\b.*\b(gan deadline|qua han|can xu ly|uu tien|gap|hom nay)\b'),
      RegExp(r'\b(con bao nhieu|bao nhieu)\b.*\b(task|nhiem vu|cong viec|viec)\b'),
      RegExp(r'\b(pending|inprogress|completed|dang cho|dang lam|da hoan thanh|da huy|huy)\b.*\b(task|nhiem vu|cong viec|viec)\b'),
      RegExp(r'\b(chia lich|sap xep|toi uu|dieu chinh|xep lai)\b.*\b(hom nay|ngay hom nay)\b'),
      RegExp(r'\b(toi chi con|chi con|con)\b.*\b(15 phut|30 phut|1 tieng|2 tieng|buoi toi|it thoi gian)\b'),
      RegExp(r'\b(category|danh muc|hoc tap|cong viec|ca nhan)\b.*\b(hom nay|uu tien|deadline|qua nhieu|gan han)\b'),
      RegExp(r'\b(nguoi anh em|cuu toi|toi dang luoi|hoi roi|dang roi)\b.*\b(hom nay|nen lam gi|viec nao|task nao)\b'),
      RegExp(r'\bgio\b.*\b(toi|minh|em|tui)\b.*\bnen lam gi\b'),
    ];

    return dynamicPatterns.any((pattern) => pattern.hasMatch(text));
  }
}

class _LocalReplyRule {
  _LocalReplyRule({
    required List<String> patterns,
    required this.reply,
  }) : patterns = patterns
      .map((pattern) => RegExp(pattern, caseSensitive: false))
      .toList(growable: false);

  final List<RegExp> patterns;
  final String reply;

  bool matches(String text) {
    return patterns.any((pattern) => pattern.hasMatch(text));
  }
}
