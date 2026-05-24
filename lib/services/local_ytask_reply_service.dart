/// Local, no-AI replies for common YTask chatbot questions.
///
/// Purpose:
/// - Answer fixed FAQ/help questions without calling Gemini.
/// - Save AI quota for questions that actually need task data or reasoning.
/// - Keep answers short enough for mobile chat UI.
///
/// Usage in chatbot_screen.dart:
///
/// ```dart
/// import 'package:todo_app/features/chatbot/local_ytask_reply.dart';
///
/// final localReply = LocalYTaskReplyService.getReply(text);
/// if (localReply != null) {
///   aiReply = localReply;
/// } else {
///   // Continue existing Gemini / task consultation flow.
/// }
/// ```
class LocalYTaskReplyService {
  const LocalYTaskReplyService._();

  /// Returns a ready-made Vietnamese answer if [userMessage] is a safe local FAQ.
  ///
  /// Returns null when the message should continue to the normal AI flow,
  /// especially questions that need real task data such as:
  /// "Hôm nay tôi nên làm gì trước?", "Task nào gần deadline nhất?",
  /// "Tôi còn bao nhiêu task pending?"
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

    // Do not intercept dynamic personal-task questions.
    // These should go to the real task consultation flow, not static FAQ.
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

  static final List<_LocalReplyRule> _rules = <_LocalReplyRule>[
    _LocalReplyRule(
      patterns: <String>[
        r'\bytask\b.*\b(la gi|dung de lam gi|co tac dung gi|de lam gi)\b',
        r'\bung dung\b.*\bytask\b.*\b(la gi|dung de lam gi|co tac dung gi)\b',
        r'\bytask\b.*\b(quan ly cong viec|quan ly nhiem vu)\b',
        r'\bytask\b.*\b(huu ich|co ich|giup duoc gi|co gi hay|loi ich|co loi ich)\b',
        r'\bwhat is ytask\b',
        r'\bwhat is ytask ai\b',
        r'\byou are ytask ai\b',
        r'\bytask ai\b',
      ],
      reply:
      'YTask là ứng dụng quản lý công việc cá nhân. App giúp bạn tạo nhiệm vụ, đặt thời gian, độ ưu tiên, nhắc nhở, theo dõi tiến độ và xử lý việc quá hạn. Điểm hữu ích nhất là YTask giúp bạn biết hôm nay nên tập trung vào việc nào trước.',
    ),
    _LocalReplyRule(
      patterns: <String>[
        r'\b(chatbot|tro ly ai|ai)\b.*\b(dung de lam gi|lam duoc gi|ho tro gi|co tac dung gi)\b',
        r'\bban\b.*\b(la ai|lam duoc gi)\b',
        r'\bwho are you\b',
        r'\bytask assistant\b',
      ],
      reply:
      'Mình là trợ lý AI trong YTask. Mình có thể hướng dẫn cách dùng app, gợi ý sắp xếp công việc, hỗ trợ lập kế hoạch và tạo bản nháp nhiệm vụ từ câu chat tự nhiên để bạn xác nhận trước khi lưu.',
    ),
    _LocalReplyRule(
      patterns: <String>[
        r'\b(dashboard|trang chu|man hinh chinh)\b.*\b(la gi|dung de lam gi|co gi)\b',
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
        r'\b(lam sao|cach|huong dan|lam the nao)\b.*\b(tao|them)\b.*\b(nhiem vu|task|cong viec)\b',
        r'\b(tao|them)\b.*\b(nhiem vu|task|cong viec)\b.*\b(nhu the nao|o dau|bang cach nao)\b',
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
      'Bạn mở chi tiết nhiệm vụ, sau đó chỉnh các thông tin như tiêu đề, thời gian, trạng thái, vị trí hoặc nhắc nhở. Khi lưu xong, dữ liệu sẽ được cập nhật.',
    ),
    _LocalReplyRule(
      patterns: <String>[
        r'\b(lam sao|cach|huong dan|lam the nao)\b.*\b(xoa|huy)\b.*\b(nhiem vu|task|cong viec)\b',
        r'\b(xoa|huy)\b.*\b(nhiem vu|task|cong viec)\b.*\b(nhu the nao|o dau|bang cach nao)\b',
      ],
      reply:
      'Bạn mở nhiệm vụ cần xử lý rồi chọn thao tác hủy hoặc xóa nếu màn hình có hỗ trợ. Nên kiểm tra kỹ trước khi xác nhận để tránh mất dữ liệu.',
    ),
    _LocalReplyRule(
      patterns: <String>[
        r'\b(lam sao|cach|huong dan|lam the nao)\b.*\b(hoan thanh|done|complete)\b.*\b(nhiem vu|task|cong viec)\b',
        r'\b(danh dau|dat)\b.*\b(nhiem vu|task|cong viec)\b.*\b(hoan thanh|da xong)\b',
      ],
      reply:
      'Bạn mở chi tiết nhiệm vụ rồi dùng nút hoặc hành động “Hoàn thành”. Khi hoàn thành, nhiệm vụ sẽ chuyển sang trạng thái completed.',
    ),
    _LocalReplyRule(
      patterns: <String>[
        r'\bprogress\b.*\b(la gi|dung de lam gi|co tac dung gi|co gi)\b',
        r'\b(theo doi tien do|tien do cong viec)\b.*\b(o dau|nhu the nao|la gi)\b',
      ],
      reply:
      'Progress là màn hình theo dõi tiến độ công việc. Bạn có thể xem tình trạng nhiệm vụ như đang chờ, đang làm, đã hoàn thành hoặc đã hủy.',
    ),
    _LocalReplyRule(
      patterns: <String>[
        r'\b(profile|tai khoan|ca nhan)\b.*\b(la gi|dung de lam gi|co gi)\b',
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
      'Nhiệm vụ quá hạn là nhiệm vụ đã qua thời gian kết thúc nhưng chưa được hoàn thành. Đây là việc nên được xử lý sớm để tránh dồn việc.',
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
        r'\b(thap|trung binh|cao)\b.*\b(la gi|priority|do uu tien)\b',
      ],
      reply:
      'Độ ưu tiên giúp bạn biết nhiệm vụ nào quan trọng hơn. YTask thường dùng 3 mức: Thấp, Trung bình và Cao.',
    ),
    _LocalReplyRule(
      patterns: <String>[
        r'\breminder\b.*\b(la gi|dung de lam gi|co tac dung gi)\b',
        r'\bnhac nho\b.*\b(la gi|dung de lam gi|co tac dung gi|nhu the nao)\b',
        r'\b(lam sao|cach|huong dan|lam the nao)\b.*\b(dat|them|tao)\b.*\b(nhac nho|reminder)\b',
      ],
      reply:
      'Nhắc nhở giúp bạn không quên nhiệm vụ. Khi tạo hoặc sửa nhiệm vụ, bạn có thể đặt nhắc trước thời gian bắt đầu hoặc trước deadline nếu app đang hỗ trợ.',
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
        r'\bai\b.*\b(co tu tao|tu luu|tu ghi|tu them)\b.*\b(nhiem vu|task|cong viec)\b',
        r'\bban\b.*\b(co tu tao|tu luu|tu ghi|tu them)\b.*\b(nhiem vu|task|cong viec)\b',
        r'\btao\b.*\b(nhiem vu|task|cong viec)\b.*\b(bang ai|tu ngon ngu tu nhien)\b.*\b(nhu the nao|duoc khong)\b',
      ],
      reply:
      'AI có thể tạo bản nháp nhiệm vụ từ câu chat tự nhiên, nhưng không tự lưu ngay. Bạn cần xem lại thông tin và bấm “Tạo nhiệm vụ” thì nhiệm vụ mới được lưu vào YTask.',
    ),
    _LocalReplyRule(
      patterns: <String>[
        r'\bai\b.*\b(co doc|co xem|xem duoc|doc duoc)\b.*\b(nhiem vu|task|cong viec)\b',
        r'\bban\b.*\b(co doc|co xem|xem duoc|doc duoc)\b.*\b(nhiem vu|task|cong viec)\b',
        r'\bdu lieu\b.*\b(nhiem vu|task|cong viec)\b.*\b(cua toi|nguoi dung rieng)\b',
      ],
      reply:
      'Với câu hỏi tư vấn kế hoạch, YTask có thể dùng nhiệm vụ của tài khoản đang đăng nhập để gợi ý. Mình không tự bịa dữ liệu và không tự lưu thay đổi nếu bạn chưa xác nhận.',
    ),
    _LocalReplyRule(
      patterns: <String>[
        r'\b(firebase|firestore)\b.*\b(la gi|dung de lam gi|luu gi)\b',
        r'\bdu lieu\b.*\b(luu o dau|duoc luu o dau|luu bang gi)\b',
      ],
      reply:
      'YTask dùng Firebase để xác thực tài khoản và lưu dữ liệu nhiệm vụ. Mỗi người dùng đăng nhập sẽ có dữ liệu riêng theo tài khoản của mình.',
    ),
    _LocalReplyRule(
      patterns: <String>[
        r'\b(dang nhap|login)\b.*\b(dung de lam gi|tai sao can|de lam gi)\b',
        r'\b(tai sao|vi sao)\b.*\b(can dang nhap|phai dang nhap)\b',
      ],
      reply:
      'Bạn cần đăng nhập để YTask lưu và đồng bộ nhiệm vụ theo tài khoản riêng. Nhờ vậy dữ liệu của bạn không bị lẫn với người dùng khác.',
    ),
    _LocalReplyRule(
      patterns: <String>[
        r'\b(lam sao|cach|huong dan|lam the nao)\b.*\b(dang ky|tao tai khoan)\b',
        r'\b(dang ky|tao tai khoan)\b.*\b(nhu the nao|o dau|bang cach nao)\b',
      ],
      reply:
      'Bạn mở màn hình đăng ký, nhập thông tin tài khoản theo yêu cầu rồi xác nhận. Sau khi đăng ký thành công, bạn có thể đăng nhập để sử dụng YTask.',
    ),
    _LocalReplyRule(
      patterns: <String>[
        r'\b(lam sao|cach|huong dan|lam the nao)\b.*\b(dang nhap|login)\b',
        r'\b(dang nhap|login)\b.*\b(nhu the nao|o dau|bang cach nao)\b',
      ],
      reply:
      'Bạn vào màn hình đăng nhập, nhập email và mật khẩu đã đăng ký. Nếu thông tin đúng, app sẽ chuyển bạn vào màn hình chính.',
    ),
    _LocalReplyRule(
      patterns: <String>[
        r'\b(light mode|dark mode|giao dien sang|giao dien toi)\b',
        r'\bdoi\b.*\b(giao dien|theme|che do sang|che do toi)\b',
      ],
      reply:
      'Nếu app có hỗ trợ giao diện sáng/tối, bạn có thể đổi trong phần cài đặt hoặc theo chế độ hệ thống. Tùy bản hiện tại, mục này có thể chưa được mở đầy đủ.',
    ),
    _LocalReplyRule(
      patterns: <String>[
        r'\b(task|nhiem vu|cong viec)\b.*\b(co nhung thong tin gi|gom nhung gi|can nhap gi)\b',
        r'\btao\b.*\b(task|nhiem vu|cong viec)\b.*\b(can nhap gi|gom nhung gi)\b',
      ],
      reply:
      'Một nhiệm vụ trong YTask có thể gồm: tên, mô tả, thời gian bắt đầu, thời gian kết thúc, nhãn, độ ưu tiên, vị trí và nhắc nhở.',
    ),
    _LocalReplyRule(
      patterns: <String>[
        r'\bten\b.*\b(nhiem vu|task|cong viec)\b.*\b(bat buoc|co can)\b',
        r'\b(nhiem vu|task|cong viec)\b.*\b(khong co ten|thieu ten)\b',
      ],
      reply:
      'Tên nhiệm vụ là thông tin quan trọng và nên bắt buộc có. Bạn nên đặt tên ngắn, rõ việc cần làm để dễ theo dõi.',
    ),
    _LocalReplyRule(
      patterns: <String>[
        r'\bdeadline\b.*\b(la gi|nghia la gi|dung de lam gi)\b',
        r'\bthoi gian ket thuc\b.*\b(la gi|dung de lam gi|nghia la gi)\b',
      ],
      reply:
      'Deadline là thời điểm nhiệm vụ cần hoàn thành. Trong YTask, bạn có thể dùng thời gian kết thúc để biết việc nào sắp đến hạn hoặc đã quá hạn.',
    ),
    _LocalReplyRule(
      patterns: <String>[
        r'\bthoi gian bat dau\b.*\b(la gi|dung de lam gi|nghia la gi)\b',
        r'\bstart time\b.*\b(la gi|dung de lam gi)\b',
      ],
      reply:
      'Thời gian bắt đầu cho biết khi nào bạn dự định làm nhiệm vụ. Nó giúp YTask sắp xếp lịch và gợi ý thứ tự làm việc hợp lý hơn.',
    ),
    _LocalReplyRule(
      patterns: <String>[
        r'\b(sap xep|uu tien)\b.*\b(theo deadline|theo thoi han)\b.*\b(la gi|nhu the nao)\b',
        r'\b(sap xep|uu tien)\b.*\b(theo do uu tien|priority)\b.*\b(la gi|nhu the nao)\b',
      ],
      reply:
      'Thông thường, bạn nên ưu tiên việc quá hạn hoặc gần deadline trước, sau đó đến việc có độ ưu tiên cao. Việc nhỏ và chưa gấp có thể để sau.',
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
        r'\b(het request|quota|rate limit|resource exhausted)\b',
        r'\bai\b.*\b(het luot|khong tra loi|qua tai|bi gioi han)\b',
      ],
      reply:
      'Lỗi này thường do app gọi AI quá nhiều trong thời gian ngắn hoặc vượt quota của Gemini/Firebase. Các câu hỏi hướng dẫn cơ bản nên trả lời local để tiết kiệm request.',
    ),
    _LocalReplyRule(
      patterns: <String>[
        r'\b(tai sao|vi sao)\b.*\b(chatbot|ai)\b.*\b(tra loi cham|lau|mat thoi gian)\b',
        r'\b(chatbot|ai)\b.*\b(cham|lau|loading lau)\b',
      ],
      reply:
      'AI có thể trả lời chậm khi mạng yếu, quota gần hết hoặc câu hỏi cần phân tích nhiều dữ liệu. Với câu hỏi hướng dẫn cơ bản, YTask nên trả lời local để nhanh hơn.',
    ),
    _LocalReplyRule(
      patterns: <String>[
        r'\b(testcase|demo)\b.*\b(chatbot|ai)\b.*\b(can gi|nen lam gi)\b',
        r'\b(chatbot|ai)\b.*\b(demo|bao ve do an)\b.*\b(can gi|nen lam gi)\b',
      ],
      reply:
      'Khi demo, nên hỏi các câu ngắn về cách dùng app, kế hoạch hôm nay, deadline, ưu tiên và trạng thái nhiệm vụ. Câu FAQ nên trả lời local, câu cần dữ liệu task mới gọi AI.',
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
      RegExp(r'\b(lam sao|cach|huong dan|lam the nao|o dau|nhu the nao|bang cach nao)\b'),
      RegExp(r'\b(la gi|dung de lam gi|co tac dung gi|nghia la gi)\b'),
      RegExp(r'\b(duoc khong|co duoc khong|co the|co tao duoc|tao duoc|them duoc)\b'),
      RegExp(r'\b(bang|voi)\s*(ai|ytask ai|tro ly|chatbot|ngon ngu tu nhien|cau chat)\b'),
    ];

    return helpWords.any((pattern) => pattern.hasMatch(text));
  }

  static bool _looksLikePersonalTaskConsultation(String text) {
    final dynamicPatterns = <RegExp>[
      RegExp(r'\bhom nay\b.*\b(toi|minh|em|tui|tao)\b.*\b(nen|can|co|con)\b'),
      RegExp(r'\b(toi|minh|em|tui|tao)\b.*\bhom nay\b.*\b(nen|can|co|con)\b'),
      RegExp(r'\b(ke hoach|lich lam viec|lich trinh)\b.*\bhom nay\b'),
      RegExp(r'\b(task nao|nhiem vu nao|viec nao|cong viec nao)\b.*\b(gan deadline|deadline|qua han|uu tien|quan trong|lam truoc|gap|can xu ly)\b'),
      RegExp(r'\b(co task nao|co nhiem vu nao|co viec nao)\b.*\b(gan deadline|qua han|can xu ly|uu tien|gap)\b'),
      RegExp(r'\b(con bao nhieu|bao nhieu)\b.*\b(task|nhiem vu|cong viec)\b'),
      RegExp(r'\b(pending|inprogress|completed|cancelled|dang cho|dang lam|da hoan thanh|da huy)\b.*\b(task|nhiem vu|cong viec)\b'),
      RegExp(r'\b(chia lich|sap xep|toi uu|dieu chinh)\b.*\b(hom nay|ngay hom nay)\b'),
      RegExp(r'\b(toi chi con|chi con|con)\b.*\b(15 phut|30 phut|1 tieng|2 tieng|buoi toi|it thoi gian)\b'),
      RegExp(r'\b(category|danh muc|hoc tap|cong viec|ca nhan)\b.*\b(hom nay|uu tien|deadline|qua nhieu)\b'),
      RegExp(r'\b(nguoi anh em|toi hoi roi|cuu toi|toi dang luoi|toi hoi roi)\b.*\b(hom nay|nen lam gi|viec nao)\b'),
    ];

    return dynamicPatterns.any((pattern) => pattern.hasMatch(text));
  }

  static String normalize(String input) {
    return input
        .toLowerCase()
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
