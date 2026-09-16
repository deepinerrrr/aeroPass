import 'package:get/get.dart';
import '../../modules/main_navigation/main_navigation_view.dart';
import '../../modules/home/home_view.dart';
import '../../modules/practice/practice_view.dart';
import '../../modules/memorize/memorize_view.dart';
import '../../modules/wrong/wrong_view.dart';
import '../../modules/favorite/favorite_view.dart';
import '../../modules/stats/stats_view.dart';
import '../../modules/search/search_view.dart';
import '../../modules/settings/settings_view.dart';
import '../../modules/mock_exam/mock_exam_view.dart';
import '../../modules/question_card/question_card_view.dart';
import '../../modules/question_bank/question_bank_view.dart';
import '../../modules/tools/collection_detail_view.dart';
import '../../modules/tools/collection_list_view.dart';
import 'routes.dart';

class AppPages {
  static final pages = [
    GetPage(
      name: Routes.main,
      page: () => const MainNavigationView(),
    ),
    GetPage(
      name: Routes.home,
      page: () => const HomeView(),
    ),
    GetPage(
      name: Routes.practice,
      page: () => const PracticeView(),
    ),
    GetPage(
      name: Routes.memorize,
      page: () => const MemorizeView(),
    ),
    GetPage(
      name: Routes.wrong,
      page: () => const WrongView(),
    ),
    GetPage(
      name: Routes.favorite,
      page: () => const FavoriteView(),
    ),
    GetPage(
      name: Routes.stats,
      page: () => const StatsView(),
    ),
    GetPage(
      name: Routes.search,
      page: () => const SearchView(),
    ),
    GetPage(
      name: Routes.settings,
      page: () => const SettingsView(),
    ),
    GetPage(
      name: Routes.mockExam,
      page: () => const MockExamView(),
    ),
    GetPage(
      name: Routes.questionCard,
      page: () => const QuestionCardView(),
    ),
    GetPage(
      name: Routes.questionBank,
      page: () => const QuestionBankView(),
    ),
    GetPage(
      name: Routes.collectionDetail,
      page: () => const CollectionDetailView(),
    ),
    GetPage(
      name: Routes.collectionList,
      page: () => const CollectionListView(),
    ),
  ];
}
