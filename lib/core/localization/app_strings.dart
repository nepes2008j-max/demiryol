import '../../data/models/attachment_type.dart';
import '../../data/models/vehicle.dart';
import '../../domain/models/securing_placement.dart';

/// Centralized Turkmen-language UI text. Every user-visible string in this
/// application — screens, widgets, and the engineering validator's check
/// labels/details — is defined here, so there is exactly one place to
/// audit for stray English text.
///
/// What is deliberately NOT translated: handbook designations (T-54,
/// KGUUB-1G, Ş-303...), paragraph/table citations (para. 31, Table 7),
/// measurements, and units — translating those would change their
/// technical meaning or break traceability back to the source handbook.
///
/// This is machine-produced professional-register Turkmen. As with the
/// English paraphrases already noted in the handbook extraction, treat it
/// as a strong first pass and have a native technical speaker review it
/// before operational use.
class AppStrings {
  AppStrings._();

  // ---- App-wide ----
  static const appTitle = 'Harby demir ýol ýükleme simulýatory';

  // ---- Common async states ----
  static String errorPrefix(Object error) => 'Ýalňyşlyk: $error';

  // ---- Main menu ----
  static const mainMenuHeading = 'HARBY DEMIR ÝOL ÝÜKLEME SIMULÝATORY';
  static const mainMenuSubtitle =
      'Bilim maksatly inžener-tehniki trenažýor — göni çeşme gollanma esasynda '
      'gurlan. Çykarylan maglumatlarda ýok bahalar hiç haçan çak edilmän, '
      'elýeterli däl diýlip görkezilýär.';
  static const startSimulationButton = 'Simulýasiýa başla — Tehnika saýla';
  static const referenceBrowserButton = 'Gollanma salgylanmalar bazasy';
  static const mainMenuSource =
      'Çeşme: Goşun bölümlerini demir ýol, suw we howa ulaglary bilen daşamagyň '
      'Kadalary — 145/175-ö belgili bilelikdäki Buýruk, 2019-njy ýylyň 3-nji iýuly';

  // ---- Vehicle selection ----
  static const vehicleSelectionTitle = 'TEHNIKA SAÝLAMAK';
  static String failedToLoadVehicles(Object error) =>
      'Tehnikalaryň sanawyny ýüklemek başartmady: $error';
  static const searchByDesignationHint = 'At ýa-da belgi boýunça gözle...';
  static const noVehiclesMatchFilter = 'Bu süzgüje gabat gelýän tehnika ýok.';
  static const vehicleDetailsTooltip = 'Tehnika barada giňişleýin maglumat';

  // ---- Platform selection ----
  static String failedToLoadPlatforms(Object error) =>
      'Platformalaryň sanawyny ýüklemek başartmady: $error';
  static const platformDetailsTooltip = 'Platforma barada giňişleýin maglumat';

  // ---- Simulation (positioning) ----
  static const simulationPositioningRule =
      'Gollanma kadasy: tehnika platformanyň uzynlygyna okunyň merkezinde '
      'ýerleşdirilmeli; sag we çep ýapyşyklaryň tapawudy 40 mm-den geçmeli '
      'däl (34-nji madda).';

  // ---- Engineering analysis ----
  static const engineeringAnalysisTitle = 'INŽENER-TEHNIKI SELJERME';
  static const completeSelectionFirst = 'Ilki tehnika we platforma saýlamagy tamamlaň.';
  static const validationChecksHeading = 'BARLAG NETIJELERI';

  /// The checks that belong to the train rather than to one machine — the deck
  /// budget, the guard wagon, the echelon class. They are counted in the mark
  /// exactly like the per-vehicle ones, so the trainee has to be able to read
  /// them.
  static const consistChecksHeading = 'DÜZÜM BOÝUNÇA BARLAGLAR';
  static const requiredHardwareHeading = 'ZERUR BERKITME ENJAMLARY';
  static const noHardwareResolvedYet =
      'Enjam entek kesgitlenmedi — ýokardaky barlaglara serediň.';
  // ---- Required equipment selection ----
  static const equipmentSelectTypeLabel = 'Görnüşi/ölçegi saýlaň:';
  static const equipmentApplyButton = 'Ulanyň';
  static const equipmentResultCorrectLabel = 'NETIJE: DOGRY';
  static const equipmentResultIncorrectLabel = 'NETIJE: ÝALŇYŞ';
  static const equipmentSelectedValueLabel = 'Saýlanan';
  static const equipmentRequiredValueLabel = 'Gollanma talaby';
  static const equipmentStatusUnknown = 'NÄBELLI';
  static const equipmentStatusNotConfigured = 'SAZLANMADY';
  static const equipmentStatusConfigured = 'SAZLANDY';
  static const equipmentStatusPass = 'DOGRY';
  static const equipmentStatusFail = 'ÝALŇYŞ';
  static String equipmentLashingCountLabel(int count) => 'Bu ulag üçin $count sany sim çekme zerur:';
  static String equipmentLashingItemLabel(int index) => '$index-nji sim';
  static const equipmentNoCatalogYet =
      'Bu enjam üçin çykarylan maglumatlarda saýlanyp bolýan görnüş tablisasy ýok.';
  static const equipmentSelectionCheckLabel = 'Saýlanan enjam gollanma bilen gabat gelýär';
  static String equipmentSelectionMatchDetail(String typeCode) =>
      'Saýlanan $typeCode görnüşi bu tehnika üçin gollanmada görkezilen hökmany '
      'görnüş bilen gabat gelýär.';
  static String equipmentSelectionMismatchDetail(String requiredTypeCode, String selectedTypeCode) =>
      'Gabat gelmeýär. Saýlanan $selectedTypeCode görnüşi bu tehnika üçin gollanmada '
      'görkezilen $requiredTypeCode hökmany görnüşinden tapawutlanýar.';

  static const equipmentOptionBasePlateLabel = 'Esasy plastinka (mm)';
  static const equipmentOptionCombHeightLabel = 'Daraşyň beýikligi (mm)';
  static const equipmentOptionSetWeightLabel = 'Toplumyň agramy (4 sany) (kg)';
  static const equipmentOptionPinLabel = 'Pürs ölçegi (mm)';
  static const equipmentOptionPinCountLabel = 'Pürsleriň sany';
  static const equipmentOptionCombatWeightRangeLabel = 'Söweş agram aralygy (t)';
  static const equipmentOptionSetDimensionsLabel = 'Toplumyň ölçegleri (mm)';
  static const equipmentOptionForVehiclesLabel = 'Degişli tehnikalar';
  static const equipmentOptionCoilLengthLabel = 'Standart tegelegiň uzynlygy (m)';
  static const equipmentOptionCoilWeightLabel = 'Standart tegelegiň agramy (kg)';
  static const equipmentOptionInsertLengthLabel = 'Uzynlygy';
  static const equipmentOptionChockHeightLabel = 'Duruzyjynyň beýikligi (mm)';
  static const equipmentOptionChockWidthLabel = 'Duruzyjynyň ini (mm)';
  static const equipmentWeightUnavailableForSizing =
      'Ulagyň söweş agramy çeşmede ýok. Şonuň üçin bu ölçeg üçin awtomatik '
      'tassyklama mümkin däl — aşakdaky gollanma tablisasyny synlaň.';

  // ---- Applied principles ----
  static const appliedPrinciplesHeading = 'SEBÄBI — ULANYLÝAN ÝÖRELGELER';
  static const noPrinciplesResolvedYet = 'Bu ýagdaý üçin entek ýörelge kesgitlenmedi.';
  static const viewResultButton = 'NETIJÄNI GÖR';
  static String summaryFail(int count) => 'KEMÇILIK — $count barlag başa barmady';
  static String summaryIncomplete(int count) =>
      'DOLY DÄL — $count barlag üçin gollanma maglumaty ýeterlik däl';
  static const summaryPass = 'KANAGATLANARLY — ähli çözülip bolýan barlaglar berjaý edildi';
  static String passCountLabel(int pass, int total) => '$pass/$total kanagatlanarly';

  // ---- Result ----
  static const resultTitle = 'NETIJE';
  static const noSimulationRunYet = 'Entek simulýasiýa geçirilmedi.';
  static const statusFail = 'KEMÇILIK';
  static const statusIncomplete = 'DOLY DÄL';
  static const statusPass = 'KANAGATLANARLY';
  static const checksPassedLabel = 'Kanagatlanarly barlaglar';
  static const checksFailedLabel = 'Başa barmadyk barlaglar';
  static const pendingDataLabel = 'Gollanma maglumaty garaşylýan barlaglar';
  static const hardwareResolvedLabel = 'Kesgitlenen enjamlaryň sany';
  static const referencedFiguresHeading = 'ULANYLAN GOLLANMA SURATLARY';
  static const exportPdfButton = 'PDF HASABATYNY ÇYKAR';
  static const mainMenuButton = 'BAŞ MENÝU';

  // ---- Reference browser ----
  static const referenceBrowserTitle = 'GOLLANMA SALGYLANMALAR BAZASY';
  static const tabFigures = 'SURATLAR';
  static const tabParagraphs = 'MADDALAR';
  static const tabTables = 'TABLISALAR';
  static const tabRules = 'KADALAR';
  static const tabPrinciples = 'ÝÖRELGELER';
  static const tabHardware = 'ENJAMLAR';
  static const tabVehicles = 'TEHNIKALAR';
  static const tabPlatforms = 'PLATFORMALAR';
  static const searchInCategoryHint = 'Bu bölümde gözle...';
  static const noFiguresMatch = 'Bu gözlege gabat gelýän surat ýok.';
  static const noParagraphsMatch = 'Bu gözlege gabat gelýän madda ýok.';
  static const noTablesMatch = 'Bu gözlege gabat gelýän tablisa ýok.';
  static const noRulesMatch = 'Bu gözlege gabat gelýän kada ýok.';
  static const noPrinciplesMatch = 'Bu gözlege gabat gelýän ýörelge ýok.';
  static const noHardwareMatch = 'Bu gözlege gabat gelýän enjam ýok.';
  static const noVehiclesMatch = 'Bu gözlege gabat gelýän tehnika ýok.';
  static const noPlatformsMatch = 'Bu gözlege gabat gelýän platforma ýok.';

  // ---- Handbook citation label (Vehicle: "Madda 51" / "Tablisa 7") ----
  static const paragraphCitationPrefix = 'Madda';
  static const tableCitationPrefix = 'Tablisa';

  /// A training plate. The plates are the handbook's worked drawings, and the
  /// interface already calls a drawing a *surat*.
  static const plateCitationPrefix = 'Surat';

  // ---- Reference chip & detail dialog ----
  static String noSummaryAvailableFor(String referenceId) =>
      'Bu salgylanma ($referenceId) üçin gysgaça maglumat ýok.';
  static const noSummaryPresent =
      'Bu salgylanma üçin çykarylan gollanma maglumatlarynda gysgaça beýan ýok.';
  static const relatedFiguresHeading = 'DEGIŞLI SURATLAR';
  static const relatedPrincipleHeading = 'DEGIŞLI ÝÖRELGE';
  static const relatedRuleHeading = 'DEGIŞLI KADA / USUL';

  // ---- Photo dialog ----
  static String figureLabel(String figureNumber) => 'Surat $figureNumber';
  static const photoSourceAttribution = 'Çeşme: gollanmanyň asyl resminamasyndan alnan surat';
  static String imageUnavailableMessage(String figureNumber, String caption) =>
      'Surat $figureNumber elýeterli däl: $caption';

  // ---- Common widget labels ----
  static const illustratedIn = 'ŞU SURATDA GÖRKEZILÝÄR';
  static const principleLabel = 'Ýörelge';
  static const purposeLabel = 'Maksady';
  static const physicsLabel = 'Fizikasy';
  static const engineeringReasonLabel = 'Inžener esaslandyrmasy';
  static const militaryRequirementLabel = 'Harby talap';

  // ---- Vehicle detail dialog ----
  static const classLabel = 'Synp';
  static const manufacturerLabel = 'Öndüriji';
  static const countryLabel = 'Ýurt';
  static const lengthLabel = 'Uzynlygy';
  static const widthLabel = 'Ini';
  static const heightLabel = 'Beýikligi';
  /// One weight per vehicle — its own — replacing the separate combat and
  /// transport weights the record used to carry side by side.
  static const weightLabel = 'Öz agramy';
  static const groundClearanceLabel = 'Ýerden aralygy';
  static const trackWidthLabel = 'Gusenisanyň ini';
  static const wheelbaseLabel = 'Oklaryň aralygy';
  // Kept apart from the wheelbase on the spec sheet as well as in the model:
  // this is the figure the para. 51 ground-pressure limit is computed on.
  static const trackContactLengthLabel = 'Gusenisanyň ýere degýän uzynlygy';
  static const approvedHardwareLabel = 'Tassyklanan enjam';
  static const ironSpurTypeLabel = 'Demir şpor görnüşi';
  static const ironChockBootTypeLabel = 'Demir başmak görnüşi';
  static const categoryLabel = 'Görnüşi';

  // ---- Platform detail dialog ----
  static const deckHeightLabel = 'Palubanyň beýikligi';
  static const maxAxleLoadLabel = 'Iň ýokary ok agramy (tigirli)';
  static const specialCaseMaxLabel = 'Aýratyn ýagdaý üçin iň ýokary agram (gusenisaly)';
  static const attachmentRingsLabel = 'Berkitme halkalary';
  static const tieDownRingsLabel = 'Daňma halkalary';
  static const woodSupportPositionsLabel = 'Agaç goldawlarynyň ýerleri';
  static const trainClassMaxWeightLabel = 'Otly synpynyň iň ýokary agramy';
  static const conditionalWagonCountLabel = 'Şertli wagonlaryň sany';
  static const allowedVehicleTypesLabel = 'Rugsat berlen tehnika görnüşleri';

  // ---- Attachment detail dialog ----
  static const materialLabel = 'Material';
  static const diametersAvailableLabel = 'Elýeterli diametrler';
  static const minThicknessLabel = 'Iň az galyňlyk';
  static const combatWeightRangeLabel = 'Söweş agram aralygy';
  static const usedForLabel = 'Ulanylyş ýeri';
  static const sizingRuleLabel = 'Ölçeg kadasy';

  // ---- Rule detail dialog ----
  static const appliesToLabel = 'Degişlilik';
  static const descriptionLabel = 'Beýany';
  static const conditionLabel = 'Şert';
  static const failMessageLabel = 'Kada bozulanda görkezilýän ýazgy';
  static const lookupTableNote =
      'Bu kada aýratyn bir şert boýunça däl-de, çykarylan maglumatlardaky '
      'agram/burç gözleg tablisasy boýunça çözülýär.';

  // ---- Data completeness badge ----
  static String dataCompletenessBadge(int percent) => 'MAGLUMAT $percent%';

  // ---- HandbookField "not available" wording ----
  static const notAvailableInHandbook = 'Çykarylan gollanma maglumatlarynda elýeterli däl';

  /// The same fact in three words, for cards and dense rows. The full sentence
  /// is right, but repeated down every spec row it buries the values that ARE
  /// known — a wagon card was four lines of it and two of data.
  static const notAvailableShort = 'çeşmede ýok';

  // ---- Enum label mappings (kept alongside strings so there is one
  // audit point for user-facing text, including enum-derived labels) ----
  static String vehicleCategoryLabel(VehicleCategory category) {
    switch (category) {
      case VehicleCategory.tracked:
        return 'Gusenisaly';
      case VehicleCategory.wheeled:
        return 'Tigirli';
      case VehicleCategory.unknown:
        return 'Näbelli';
    }
  }

  static String attachmentCategoryLabel(AttachmentCategory category) {
    switch (category) {
      case AttachmentCategory.rope:
        return 'Ýüp/sim çekme';
      case AttachmentCategory.chain:
        return 'Zynjyr';
      case AttachmentCategory.cable:
        return 'Trosik';
      case AttachmentCategory.woodBlock:
        return 'Agaç bölek';
      case AttachmentCategory.metalStop:
        return 'Metal duruzyjy';
      case AttachmentCategory.wheelStop:
        return 'Tigir duruzyjy';
      case AttachmentCategory.trackStop:
        return 'Gusenisa duruzyjy';
      case AttachmentCategory.woodWedge:
        return 'Agaç paz';
      case AttachmentCategory.clamp:
        return 'Gysgyç';
      case AttachmentCategory.bolt:
        return 'Çüý';
      case AttachmentCategory.specialLock:
        return 'Ýörite berkidiji';
      case AttachmentCategory.unknown:
        return 'Näbelli';
    }
  }

  /// Maps a rules.json `appliesTo` value ("wheeled" / "tracked" /
  /// "tracked_or_wheeled") to its Turkmen label. Falls back to the raw
  /// value if it doesn't match a known form, rather than hiding it.
  static String appliesToLabelFor(String appliesTo) {
    switch (appliesTo) {
      case 'wheeled':
        return 'Tigirli';
      case 'tracked':
        return 'Gusenisaly';
      case 'tracked_or_wheeled':
        return 'Gusenisaly ýa-da tigirli';
      default:
        return appliesTo;
    }
  }

  // ---- EngineeringValidator check labels/details ----



  static const symmetryUnknownDetail =
      'Simmetriýany barlamak üçin tehnikanyň ini, platformanyň ini we tehnikanyň '
      'platformadaky ýerleşişi zerur; bularyň hiç biri heniz ýazylyp alynmady. '
      '$notAvailableInHandbook.';

  static const vehicleSpecificHardwareLabel = 'Tehnika üçin ýörite enjam kesgitlendi';
  static String ironSpurResolvedDetail(String designation, String type) =>
      '$designation üçin 13-nji tablisa boýunça $type görnüşli demir şpor talap '
      'edilýär — bu hökmany bolup, erkin saýlanmaýar (31-nji madda).';
  static String ironChockBootResolvedDetail(String designation, String type) =>
      '$designation üçin 11-nji tablisa boýunça $type görnüşli demir başmak talap '
      'edilýär (32-nji madda).';


  static const wireLashingCountResolvedLabel = 'Sim çekmeleriň sany kesgitlendi';
  static String wireLashingCountDetail(int count, String weightDisplay) =>
      '$weightDisplay t söweş agramy üçin $count sany ýekeje sim çekme talap '
      'edilýär (55-nji madda).';
  static const wireLashingCountUnknownDetail =
      'Söweş agramy bu gollanma bölüminde tigirli tehnikanyň sim çekmeleri üçin '
      'görkezilen 40 t çägini geçýär. $notAvailableInHandbook.';



  static const securingMethodCheckLabel = 'Berkitme usuly saýlanan (alternatiw tassyklanan usullar)';
  static const securingMethodUnknownDetail =
      'Bu ulag üçin haýsy tassyklanan berkitme usulynyň ulanyljakdygyny kesgitlemek üçin '
      'söweş agramy zerur; ol heniz ýazylyp alynmady. $notAvailableInHandbook.';
  static String securingMethodNotSelectedDetail(List<int> methodNumbers) =>
      'Bu ulag üçin birnäçe tassyklanan alternatiw usul elýeterli '
      '(${methodNumbers.join(', ')}-nji usullar). Haýsysynyň ulanyljakdygyny saýlaň — '
      'ulgam olaryň hemmesini awtomatiki suratda bilelikde talap etmeýär.';
  static String securingMethodInvalidDetail(int selected, List<int> available) =>
      'Saýlanan $selected-nji usul bu ulagyň maglumatlary boýunça elýeterli däl. '
      'Elýeterli usullar: ${available.join(', ')}.';
  static String securingMethodAppliedUnconfirmedDetail(int methodNumber) =>
      '$methodNumber-nji usul saýlandy. Emma bu ulagyň söweş agramy çykarylan gollanma '
      'maglumatlarynda ýok, şonuň üçin usulyň agrama bagly çäkleri (KGUUB üçin 7-42 t, '
      'direg agaç bölekleriniň ölçegleri) barlanyp bilinmedi — laýyklyk tassyklanmadyk.';
  static const securingMethodEligibilityUnconfirmedNote =
      'Söweş agramy çeşmede ýok: usullar hödürlenýär, emma agrama bagly çäkler barlanyp '
      'bilinmeýär.';
  static String securingMethodAppliedDetail(int methodNumber) =>
      '$methodNumber-nji tassyklanan usul ulanyldy.';
  static const securingMethodSelectLabel = 'Berkitme usulyny saýlaň:';

  // ---- Securing-method status (vehicle card preview) ----
  static const securingStatusIronSpur = 'Berkitme: demir şpor (hökmany)';
  static const securingStatusIronChockBoot = 'Berkitme: demir başmak (hökmany)';
  // With the type code, because for these vehicles the handbook fixes exactly
  // which spur or boot is used (Table 13 / Table 11) even though it gives no
  // dimensions at all — that is the most useful thing their card can say, and
  // it was being hidden behind a "0% data" badge.
  static String securingStatusIronSpurTyped(String type) =>
      'Berkitme: demir şpor $type (hökmany)';
  static String securingStatusIronChockBootTyped(String type) =>
      'Berkitme: demir başmak $type (hökmany)';
  static const securingStatusAlternatives = 'Berkitme: alternatiw usullar bar';
  static const securingStatusAlternativesUnconfirmed =
      'Berkitme: alternatiw usullar bar (söweş agramy çeşmede ýok — laýyklyk tassyklanmaýar)';
  static const securingStatusWireLashing = 'Berkitme: sim çekme (agram esasynda)';
  static const securingStatusUnknown = 'Berkitme: kesgitlemek üçin maglumat ýeterlik däl';

  // ---- Configuration stepper ----

  // ---- Breadcrumb ----
  static const backButtonLabel = 'Yza';

  // ---- Vehicle category screen ----
  static const vehicleCategoryScreenTitle = 'ULAG GÖRNÜŞINI SAÝLAŇ';
  static const vehicleCategorySelectButton = 'SAÝLA';

  // ---- Connect (vehicle + platform) screen ----

  // ---- Equipment configuration wizard ----
  static String equipmentWizardProgress(int index, int total) => '$index / $total';
  static const equipmentWizardNext = 'Indiki komponent';
  static const equipmentWizardPrevious = 'Öňki';
  static const securingMethodStageTitle = '5. BERKITME USULY';
  static const equipmentStageTitle = '6. ENJAM SAÝLAŇ';
  static const visualStageTitle = '7. WIZUAL GÖRNÜŞ';
  static const proceedToEquipmentButton = 'ENJAMLARY SAZLA';
  static const proceedToVisualButton = 'WIZUAL GÖRNÜŞE GEÇ';
  static const backToMethodStage = 'Berkitme usulyna gaýt';
  static const backToEquipmentStage = 'Enjamlara gaýt';
  // Shown when the trainee's own placement in the 3D scene has already
  // answered the method and equipment stages, so neither is put to them again.
  static const securingAnsweredByPlacement =
      'Berkitme usuly we enjamlar 3D sahnada goýan bölekleriňizden alyndy — '
      'gaýtadan soralmaýar.';
  static const securingReviseAnswers = 'Berkitme usulyny we enjamlary üýtget';
  static String securingUnconfirmedCount(int n) => '$n sany tassyklanmadyk';
  static const selectVehicleButton = 'ULAGY SAÝLA';
  static const vehicleSelectedBadge = 'SAÝLANDY';
  static const equipmentShowDetailsButton = 'Görkez';
  static const equipmentHideDetailsButton = 'Gizle';
  static const equipmentRequiredBadge = 'Gerekli';
  static const vehiclePhotoUnavailable = 'Surat: çeşmede ýok';
  static const equipmentPhotoUnavailable = 'Bu görnüş üçin aýratyn surat çeşmede ýok.';
  static const securingRelatedFiguresHeading = 'BERKITME ÜÇIN GATNAŞYKLY FIGURALAR';

  // ---- Illustrative vehicle photograph (Wikimedia Commons, NOT a handbook
  // figure). Every one of these strings exists to keep that distinction
  // visible to the trainee: the picture helps them recognise the machine, it
  // is not evidence of how to secure it. ----
  static const illustrativePhotoBadge = 'ŞERTLI SURAT';
  static const illustrativePhotoNotice =
      'Şertli surat: ulagy tanamak üçin daşarky çeşmeden alyndy — gollanmanyň suraty däl.';
  static String illustrativePhotoDialogTitle(String designation) =>
      '$designation — şertli surat';
  static const illustrativePhotoSourceHeading = 'SURATYŇ ÇEŞMESI WE YGTYÝARNAMASY';
  static const photoAuthorLabel = 'Awtor';
  static const photoLicenseLabel = 'Ygtyýarnama';
  static const photoSourceLabel = 'Çeşme';
  static const photoAuthorUnknown = 'Awtory çeşmede görkezilmedik';

  // ---- Side elevation / flatcar scene ----
  static const sideElevationTitle = 'GAPDALDAN GÖRNÜŞ';
  static const planViewTitle = 'ÜSTDEN GÖRNÜŞ';

  // ---- Short names used as labels on the side elevation. The full name (with
  // the selected type code and Table 3 dimensions) stays on the element itself
  // and is shown when the trainee taps it; a drawing needs the short form.
  static const hardwareShortWoodChock = 'Direg agaç bölegi';
  static const hardwareShortSpacerBoard = 'Ara goýulýan agaç';
  static const hardwareShortReusableChock = 'KGUUB gysgyç';
  static const hardwareShortIronSpur = 'Demir şpor';
  static const hardwareShortIronChockBoot = 'Demir başmak';
  static const hardwareShortWireLashing = 'Sim çekme';

  // ---- Provenance of a vehicle record ----
  static const dataSourceMockupBadge = 'MAKET MAGLUMATY';
  static const dataSourceMockupTooltip =
      'Bu tehnikanyň san maglumatlary gollanmadan däl-de, taslamanyň öz dizaýn maketinden '
      'alyndy. Gollanmanyň tigirli tehnika baradaky kadalaryny synap görmek üçin goşuldy.';
  static const dataSourceMockupDetail =
      'Maglumat çeşmesi: taslamanyň dizaýn maketi (gollanmadan çykarylan maglumat däl).';

  // ---- Chock arrangement (direg ýerleşdirilişi) ----
  static const chockArrangementSectionHeading = 'DIREG AGAÇ BÖLEKLERINIŇ ÝERLEŞDIRILIŞI';
  static const chockArrangementSelectLabel = 'Ýerleşdiriş usulyny saýlaň:';
  static String chockArrangementTrackedStandard(int minCm, int maxCm) =>
      'Ýöreýiş bölekden $minCm-$maxCm sm aralykda (esasy ýerleşdiriş)';
  static String chockArrangementTrackedAlternate(int minCm, int maxCm) =>
      'Ýöreýiş bölekden $minCm-$maxCm sm aralykda (ikinji ýerleşdiriş)';
  static String chockArrangementWheeled({
    int? axles,
    double? maxWeightT,
    required bool overCoupling,
  }) {
    final weight = maxWeightT == null
        ? ''
        : ' — ${maxWeightT.toStringAsFixed(1).replaceAll('.', ',')} t çenli';
    final axleText = axles == null ? '' : '$axles okly';
    final place = overCoupling ? 'iki wagonyň tirkeginiň üstünde' : 'bir açyk wagonda';
    return '$axleText tehnika$weight, $place';
  }

  static String lateralRestraintStaples(int count) =>
      'Gapdal süýşmä garşy $count sany ýaý şekilli skoba (üç-üçden)';
  static String lateralRestraintSideBlocks(String sizeMm) =>
      'Gapdal süýşmä garşy $sizeMm mm agaç bölekleri (zynjyryň iç we daş ýüzünden)';
  static const lateralRestraintSelectLabel = 'Gapdal süýşmä garşy serişdäni saýlaň:';
  static const chockArrangementHandbookCase = 'GOLLANMA BOÝUNÇA';
  static const chockArrangementDoubled = 'sany iki esse köpeldilen';
  static const chockArrangementUnconfirmedNote =
      'Söweş agramy çeşmede ýok: ähli ýerleşdiriş ýagdaýlary hödürlenýär, emma haýsysynyň '
      'dogrudygy agrama görä tassyklanyp bilinmeýär.';
  static String chockArrangementCountLabel(int chocks, int inserts) => inserts > 0
      ? '$chocks sany direg agaç bölegi + $inserts sany ara goýulýan agaç bölegi'
      : '$chocks sany dörtgyraň agaç bölegi';
  static String chockArrangementGapLabel(int minMm, int maxMm) =>
      'Tigriň daş ýüzünden $minMm-$maxMm mm';

  // ---- End view (öňden görnüş) callouts ----
  static const endViewTitle = 'ÖŇDEN GÖRNÜŞ';
  static const endViewSubtitle =
      'Wagonyň ujundan görnüş: gapdal aralyklar we sallanma diňe şu görnüşde görünýär.';
  static String endViewGapCallout(int minMm, int maxMm) => '$minMm-$maxMm mm';
  static String endViewSeatingCallout(int minCm, int maxCm) =>
      'Ýöreýiş bölekden $minCm-$maxCm sm';
  static String endViewOverhangCallout(int maxMm) =>
      'Sallanma $maxMm mm-den köp bolmaly däl';
  static const chockDetailTitle = 'DIREG AGAÇ BÖLEGINIŇ ÝAKYNDAN GÖRNÜŞI';
  static String chockDetailNails(int count, int diameterMm, int lengthMm) =>
      '$count sany çüý ${diameterMm}x$lengthMm mm';
  static String chockDetailStaple(int minDiameterMm) =>
      'Skoba: diametri $minDiameterMm mm-den inçe bolmaly däl';

  // ---- Wagon deck budget: how much length the load uses and what is left ----
  static const wagonCapacityCheckLabel = 'Wagonyň polunyň uzynlygy ýeterlikmi';
  static const wagonCapacitySectionTitle = 'WAGONYŇ POLY — UZYNLYK HASABY';
  static const wagonCapacityNoDeckLengthDetail =
      'Wagonyň polunyň uzynlygy çykarylan gollanma maglumatlarynda ýok, şonuň üçin ýeriň '
      'ýetýändigi hasaplanyp bilinmeýär. Ölçegi el bilen girizip bilersiňiz.';
  static String wagonCapacityNoVehicleLengthDetail(String designations) =>
      'Şu tehnikanyň uzynlygy ýok: $designations. Uzynlyk bolmasa wagonda näçe ýer '
      'galýandygy hasaplanyp bilinmeýär.';
  static String wagonCapacityOverloadedDetail(String overCm, int gapMm) =>
      'Ýük wagonyň poluna sygmaýar: $overCm sm artyk (tehnikalaryň arasyndaky $gapMm mm '
      'aralyk hem hasaba alnyp).';
  static String wagonCapacityFitsDetail(String remainingCm) =>
      'Ýük wagonyň poluna sygýar — $remainingCm sm ýer galýar.';
  static String wagonCapacityDeckLabel(String cm) => 'Polunyň uzynlygy: $cm sm';
  static String wagonCapacityUsedLabel(String cm) => 'Ulanylan: $cm sm';
  static String wagonCapacityGapLabel(int maxMm, int gaps, String totalCm) =>
      'Aralyklar: $gaps sany (iň uly $maxMm mm), jemi $totalCm sm';
  static String wagonCapacityRemainingLabel(String cm) => 'Galan ýer: $cm sm';
  static const wagonCapacityRemainingUnknown = 'Galan ýer: hasaplanyp bilinmedi';

  // ---- The value strip ----
  //
  // The readings the app has actually taken on one wagon, each shown against
  // the range the handbook states for it. These are the labels beside the
  // scales; the numbers themselves are never words.
  static const measuredStripHeading = 'Ölçegler';
  static const measuredStripEmpty =
      'Heniz ölçeg alynmady. Tehnikany wagona ýerleşdiriň we berkidiş enjamyny '
      'goýuň — her goýlan enjam şu ýerde gollanmanyň çägi bilen deňeşdirilýär.';
  static const wagonBudgetUsedLabel = 'Ulanylan pol';
  static const wagonBudgetRemainingLabel = 'Galan ýer';
  static const wagonOverhangLabel = 'Sallanma';
  static const seatingDistanceLabel = 'Duruzyjynyň aralygy';
  static String wagonCapacitySpanningNote(String designations) =>
      '$designations iki wagonyň tirkeginiň üstünde dur: uzynlygy diňe birinji wagonyň '
      'hasabyna goşulýar.';
  static const enterCombatWeightButton = 'Söweş agramyny giriz';
  static const enterCombatWeightHint = 'Tonnada';
  static const wagonCapacityEnterDeckLength = 'Polunyň uzynlygyny giriz';
  static const wagonCapacityEnterVehicleLength = 'Tehnikanyň uzynlygyny giriz';
  static const wagonCapacityEnterHint = 'Santimetrde';
  static const wagonCapacityUserValueBadge = 'EL BILEN GIRIZILEN';
  static const wagonCapacityUserValueNote =
      'El bilen girizilen ölçeg — gollanmadan çykarylan maglumat däl.';
  static const wagonCapacitySaveButton = 'Ýatda sakla';
  static const wagonCapacityClearButton = 'Poz';

  static const wheeledChockRequiredLabel = 'Dörtgyraň agaç bölekleri talap edilýär';
  static const wheeledChockRequiredDetail =
      'Tigirli tehnika agramyna garamazdan dörtgyraň agaç bölekleri bilen berkidilýär; '
      'diňe sany agram toparyna baglydyr (plakat 06).';

  static const chockArrangementCheckLabel =
      'Direg agaç bölekleriniň ýerleşdirilişi saýlanan (plakatdaky ýagdaýlar)';
  static const chockArrangementNotSelectedDetail =
      'Ýerleşdiriş ýagdaýy heniz saýlanmady. Plakatda çyzylan ýagdaýlaryň birini saýlaň — '
      'hiç biri awtomatik ulanylmaýar.';
  static String chockArrangementAppliedDetail(int chocks) =>
      'Saýlanan ýerleşdiriş bu tehnikanyň agram toparyna we ok sanyna laýyk gelýär '
      '($chocks sany agaç bölegi).';
  static String chockArrangementUnconfirmedDetail(int chocks) =>
      'Ýerleşdiriş saýlandy ($chocks sany agaç bölegi). Emma bu ulagyň söweş agramy '
      'çykarylan gollanma maglumatlarynda ýok, şonuň üçin haýsy ýagdaýyň dogrudygy '
      'tassyklanyp bilinmedi.';
  static String chockArrangementWrongBracketDetail(double weightT) =>
      'Saýlanan ýerleşdiriş bu tehnikanyň agramyna (${weightT.toStringAsFixed(1)} t) ýa-da '
      'ok sanyna görä plakatda çyzylan ýagdaý däl.';
  static String chockArrangementWrongCouplingCaseDetail(bool spansCoupling) => spansCoupling
      ? 'Tehnika iki wagonyň tirkeginiň üstünde dur, emma bir wagon üçin çyzylan ýerleşdiriş '
          'saýlandy.'
      : 'Tehnika bir wagonda dur, emma tirkegiň üstündäki ýagdaý üçin çyzylan ýerleşdiriş '
          'saýlandy.';

  // ---- Wagon-type step: right and wrong wagons ----
  // ---- Attempt score and mistake log ----
  static String attemptWrongWagonEvent(String wagonName) =>
      'Ýaramaýan wagon görnüşi saýlanmaga synanyşyldy: $wagonName';

  // ---- Wire lashing angles (Table 7) ----
  static const enterAngleHint = 'Gradusda';
  static const lashingAngleHeading = 'ÇEKMÄNIŇ BURÇLARY (7-NJI TABLISA)';
  static const lashingAngleSubtitle =
      'Bu iki burç wagonda ölçelýär — gollanmada tehnika boýunça berilmeýär. '
      'Giriziljek sanlar el bilen girizilen hasaplanýar.';
  static const lashingAxisAngleShort = 'Oka burç';
  static const lashingFloorAngleShort = 'Pola burç';
  static String lashingFloorAngleCap(int maxDeg) =>
      'Pola bolan burç $maxDeg°-dan geçmeli däl.';

  // ---- Materials list (what to draw from stores) ----
  static const consumablesHeading = 'GEREKLI SERIŞDELER';
  static const consumablesSubtitle =
      'Saýlanan usul we ýerleşdiriş boýunça bir tehnika üçin hasaplanan sanlar.';
  static const consumableWoodChock = 'Direg dörtgyraň agaç bölegi';
  static const consumableInsertBlock = 'Ara goýulýan ýarym tegelek agaç bölegi';
  static const consumableNail = 'Çüý';
  static const consumableStaple = 'Ýaý şekilli demir skoba';
  static const consumableWire = 'Sim (bir nusgaly çekmeler üçin)';
  static const consumableKguub = 'KGUUB uniwersal berkidiji (toplum)';
  static const consumableIronSpur = 'Demir şpor (toplum)';
  static const consumableIronChockBoot = 'Demir direg başmak (toplum)';
  static const consumableUnitPiece = 'sany';
  static const consumableUnitMetre = 'metr';
  static const consumableReusableSet = 'köp gezek ulanylýan, 4 sanylyk toplum';
  static const consumableStapleSpec = 'diametri 12 mm-den inçe bolmaly däl';
  static String consumableWireSpec(int strands, double kg) =>
      'her çekmede $strands sapak · takmynan $kg kg';
  static String consumableStrandSourcesDiffer(int byAngle, int byWeight) =>
      '7-nji tablisa ölçenen burçlar boýunça her çekmede $byAngle sapak berýär, '
      'plakatdaky TABLISSA No.1 bolsa agram boýunça $byWeight sapak. Iki çeşme-de '
      'gollanmadan — haýsysyny ulanmalydygyny çeşme sahypasyndan anyklamaly.';
  static const consumableNeedsWeight =
      'Söweş agramy ýok — sany hasaplanyp bilinmedi.';
  static const consumableNeedsArrangement =
      'Ýerleşdiriş usuly saýlanmady — sany hasaplanyp bilinmedi.';
  static const consumablesNothingYet =
      'Berkitme usuly saýlanandan soň gerekli serişdeler şu ýerde hasaplanýar.';

  // ---- Consist-level checks: echelon class and guard wagon ----
  static const echelonCheckLabel = 'Eşelonyň düzümi (şertli wagon topary)';
  static const echelonNoClassesDetail =
      'Eşelon toparlary ýa-da wagon sany kesgitlenmedik — düzümi barlap bolmady.';
  static String echelonTooLongDetail(int wagons, int maxWagons) =>
      'Düzümde $wagons wagon bar — bu gollanmada kesgitlenen iň uly topardan '
      '($maxWagons şertli wagon) köp.';
  static String echelonFitsDetail(int wagons, int maxWagons, int maxWeightT) =>
      'Düzümdäki $wagons wagon $maxWagons şertli wagonlyk topara ($maxWeightT t çenli) '
      'sygýar. Bellik: her fiziki platforma bir şertli wagon hasaplanýar; agram boýunça '
      'barlag üçin tehnikalaryň agramy gerek.';
  static const guardWagonCheckLabel = 'Gorag wagony gerekmi (sallanma)';
  static const guardWagonNoRuleDetail =
      'Sallanma kadasy maglumatlarda tapylmady.';
  static String guardWagonUnknownDetail(int limitMm) =>
      'Sallanmany hasaplamak üçin wagonyň polunyň we tehnikanyň uzynlygy gerek. '
      'Çäk: $limitMm mm.';
  static String guardWagonRequiredDetail(int overhangMm, int limitMm) =>
      'Sallanma $overhangMm mm — $limitMm mm çäkden geçýär, gorag wagonyny goýmak '
      'hökmandyr.';
  static String guardWagonNotRequiredDetail(int overhangMm, int limitMm) =>
      'Sallanma $overhangMm mm — $limitMm mm çäginden geçmeýär, gorag wagony gerek däl.';

  // ---- Printable result sheet ----
  /// The one line under the verdict that says what the mark is of.
  static String reportVerdictLine(
          int percent, int passed, int decidable, int failed) =>
      'Baha $percent% — kesgitlenen $decidable barlagdan $passed dogry, '
      '$failed ýalňyş.';
  static String reportUndecidedLine(int unknown) =>
      'Şeýle-de $unknown barlag kesgitlenip bilinmedi; olar baha goşulmaýar.';

  static const reportTitle = 'HARBY TEHNIKANY BERKITMEK — NETIJE HASABATY';
  static String reportGeneratedAt(String when) => 'Düzülen wagty: $when';
  static String reportConsistLine(String platform, int wagons, int vehicles) =>
      'Düzüm: $platform · $wagons wagon · $vehicles sany tehnika';
  static const reportColumnCheck = 'Barlag';
  static const reportColumnVerdict = 'Netije';
  static const reportColumnDetail = 'Düşündiriş';
  static const reportColumnSource = 'Çeşme';
  /// The checks that belong to the train rather than to one machine — the
  /// deck budget, the guard wagon, the echelon class.
  static const reportConsistChecksHeading = 'DÜZÜM BOÝUNÇA BARLAGLAR';
  static const reportStatusHeader = 'Netije';
  static const reportStatusPass = 'Dogry';
  static const reportStatusFail = 'Ýalňyş';
  static const reportStatusUnknown = 'Kesgitlenmedik';
  static const reportFooterNote =
      'Kesgitlenmedik barlaglar baha goşulmaýar: olar üçin gerekli ölçegler çykarylan '
      'gollanma maglumatlarynda ýok. El bilen girizilen ölçeglere esaslanýan netijeler '
      'gollanmadan çykarylan maglumat däldir.';
  static String reportSavedTo(String path) => 'Hasabat ýatda saklandy: $path';
  static const reportFailed = 'Hasabaty düzüp bolmady.';

  static const attemptScoreHeading = 'BAHA';
  static const attemptScoreNothingDecidable =
      'Hiç bir barlag kesgitlenip bilinmedi — baha goýup bolmaýar. Ölçegleri giriziň.';
  static String attemptScorePercent(int percent) => '$percent%';
  static String attemptScoreDecidable(int passed, int decidable) =>
      'Kesgitlenen barlaglar: $passed / $decidable dogry';
  static String attemptScoreUnknown(int count) =>
      'Kesgitlenip bilinmedik barlaglar: $count (baha goşulmaýar)';
  static String attemptScoreMistakes(int count) => 'Ýalňyş hereketler: $count';

  // The same three figures as readings, with the number read off the value
  // column instead of being spliced into a sentence. The sentences above are
  // kept for the exported report, which has no columns to align to.
  static const attemptScoreDecidableLabel = 'Kesgitlenen barlaglar';
  static const attemptScoreUnknownLabel = 'Kesgitlenip bilinmedik';
  static const attemptScoreMistakesLabel = 'Ýalňyş hereketler';
  static const attemptMistakesHeading = 'ÝALŇYŞLYKLAR';
  static const attemptNoMistakes = 'Ýalňyşlyk hasaba alynmady.';

  static const wagonTypeNeedsWagonCount =
      'Ilki wagonlaryň sanyny kesgitläň — wagon görnüşi saýlanandan soň düzüm şol sana görä gurulýar.';
  static const wagonNotApprovedBadge = 'ÝARAMAÝAR';
  static const wagonRejectedHeading = 'BU WAGON GÖRNÜŞI ÝARAMAÝAR';
  static const wagonChooseCorrectHint =
      'Harby tehnikany ýüklemek üçin dogry wagon görnüşini saýlaň.';
  static String vehicleSelectionTitleForCategory(String categoryLabel) =>
      '${AppStrings.vehicleSelectionTitle} — ${categoryLabel.toUpperCase()}';

  // ---- Configuration status panel ("what's missing / next step") ----
  static const configurationStatusTitle = 'KONFIGURASIÝANYŇ ÝAGDAÝY';
  static String configurationVehicleSelectedLabel(String designation) =>
      'Ulag saýlandy: $designation';
  static String configurationPlatformSelectedLabel(String name) =>
      'Platforma saýlandy: $name';
  static const configurationMethodPendingLabel = 'Berkitme usuly heniz saýlanmady';
  static const configurationMethodSelectedLabel = 'Berkitme usuly saýlandy';
  static const configurationMethodInvalidLabel = 'Saýlanan berkitme usuly nädogry';
  static const configurationMethodUnknownLabel =
      'Berkitme usulyny kesgitlemek üçin maglumat ýeterlik däl';
  static String configurationEquipmentPendingLabel(String name) => '$name görnüşi saýlanmady';
  static String configurationEquipmentMismatchLabel(String name) =>
      '$name: saýlanan görnüş gollanma bilen gabat gelmeýär';
  static String configurationEquipmentOkLabel(String name) => '$name konfigurasiýa edildi';
  static String configurationEquipmentInfoLabel(String name) =>
      '$name — görnüş saýlamak islege bagly maglumat üçin peýdaly';
  static const configurationNextStepLabel = 'Indiki ädim:';
  static const configurationNextStepChooseMethod = 'Berkitme usulyny saýlaň.';
  static String configurationNextStepChooseType(String name) => '$name üçin görnüşi saýlaň.';
  static String configurationNextStepFixMismatch(String name) =>
      '$name üçin nädogry saýlanan görnüşi düzediň.';
  static const configurationSummaryHeading = 'BERKITME KONFIGURASIÝASY';
  static const configurationSummaryVehicleLabel = 'Ulag';
  static const configurationSummaryPlatformLabel = 'Platforma';
  static const configurationSummaryMethodLabel = 'Berkitme usuly';
  static const configurationSummaryMethodPending = 'Heniz saýlanmady';
  static const configurationSummaryEquipmentHeading = 'Enjamlar';
  static String configurationSummaryEquipmentLine(String name, String? type) =>
      type == null ? name : '$name — $type';
  static const configurationSummaryEquipmentPending = 'saýlanmady';
  static String configurationSummaryConfiguredCount(int configured, int total) =>
      '$configured/$total komponent konfigurasiýa edildi';
  static String configurationSummaryMatchingCount(int matching, int scored) =>
      '$matching/$scored komponent çeşme bilen laýyk gelýär';
  static const configurationSummaryUnknownHeading = 'Näbelli galýan barlaglar';
  static const configurationSummaryAnalysisButton = 'INŽENER-TEHNIKI BARLAG';

  static const configurationCompleteLabel =
      'Konfigurasiýa doly. Saýlanan enjamlary platformada barlaň we Inžener-tehniki barlagy geçiriň.';

  // ---- Vehicle detail dialog: securing-relevant data checklist ----
  static const requiredDataForSecuringHeading = 'BERKITMÄ ÜÇIN ZERUR MAGLUMATLAR';
  static const requiredDataSecuringMethodLabel = 'Berkitme usuly';
  static const requiredDataWeightLabel = 'Ulagyň agramy';
  static const requiredDataDimensionsLabel = 'Ulagyň ölçegleri (uzynlyk/ini/beýikligi)';
  static const requiredDataAvailable = 'çeşmede bar';
  static const requiredDataUnavailable = 'çeşmede ýok';

  // ---- Vehicle analysis panel (shown right after vehicle selection) ----

  static const hardwareResolutionFallbackLabel = 'Berkitme enjamy kesgitlendi';
  static const hardwareResolutionFallbackDetail =
      'Bu tehnika üçin näme ýörite enjam görnüşi, näme-de ulanyp bolýan söweş '
      'agramy heniz elýeterli däl. $notAvailableInHandbook.';

  // ---- Securing schematic ----
  static const schematicSectionTitle = 'GÜÝÇLENDIRIP BERKITMÄNIŇ SHEMASY';
  static const schematicNotToScaleBanner = 'ŞEMATIK GÖRNÜŞ — MASŞTABDA DÄL';
  static const schematicNotToScaleExplanation =
      'Takyk ölçegler (uzynlyk, ini, aralyk) çykarylan gollanma maglumatlarynda '
      'ýok bolany üçin, bu shema diňe gurluşy düşündirmek maksatly şertli suratdyr.';
  static const schematicNoHardwareYet =
      'Bu tehnika-platforma jübüti üçin berkitme enjamy heniz kesgitlenmedi.';
  static const schematicLegendVehicle = 'Tehnika (şertli ölçegde)';
  static const schematicLegendPlatform = 'Platforma (şertli ölçegde)';
  static const schematicLegendRailDirection = 'Demir ýol ugry (şertli)';
  static const schematicLegendSymmetryAxis = 'Simmetriýa oky (34-nji madda)';
  static const schematicLegendTrackWheelRun = 'Gusenisa/tigir yzy (şertli)';
  static const schematicLegendHardware = 'Berkitme enjamynyň ýerleşişi (şertli)';
  static const schematicLegendAttachmentPoint = 'Berkitme nokady (şertli)';
  static const schematicLegendMismatch = 'Saýlanan enjam gollanma bilen gabat gelmeýär';
  static const schematicLegendSpacerBoard = 'Aralyk tagtasy (şertli)';
  static const schematicTapHint = 'Jikme-jiklikleri görmek üçin islendik enjama ýa-da ulaga basyň.';
  static const schematicElementDetailFallbackTitle = 'Şematik enjam';
  static const schematicElementTypeLabel = 'Görnüş';
  static const schematicElementStatusHeading = 'ÝAGDAÝY';
  static const schematicElementSpecsHeading = 'ÖLÇEGLER';
  static const schematicElementCitationHeading = 'GOLLANMA SALGY';
  static const schematicElementMismatchNote =
      'Bu saýlaw gollanmada bu ulag üçin talap edilýän görnüş bilen gabat gelmeýär.';
  static const schematicElementPlacementSupportedNote =
      'Bu gatnaşyk (ýerleşiş) çykarylan gollanma tekstinde aç-açan beýan edilýär.';

  static const schematicSymmetryAxisLabel = 'Simmetriýa oky';
  static const schematicTrackRunLabel = 'Gusenisa yzy';
  static const schematicWheelRunLabel = 'Tigir';
  static const schematicAttachmentPointLabel = 'Berkitme nokady';

  static String schematicPairLabel(int index, String hardwareLabel) =>
      '$index-nji jübüt: $hardwareLabel';

  // ---- Interactive schematic positioning ----
  static const schematicDragHint =
      'Tehnikany basyp süýräň — diňe şertli görnüşi üýtgedýär, ölçeg däl.';
  static const schematicResetButton = 'Başlangyç ýagdaýyna dikelt';
  static const schematicPositionInitial = 'Başlangyç (merkezi) ýagdaýda';
  static const schematicPositionAdjusted = 'Ulanyjy tarapyndan şertli süýşürildi';
  static const schematicStatusSectionTitle = 'ÝERLEŞIŞ WE BARLAG ÝAGDAÝY';
  static const schematicStatusPositionLabel = 'Şematik ýerleşiş';
  static const schematicStatusHandbookLabel = 'Gollanma gatnaşygy';
  static const schematicStatusHandbookText =
      'Tehnika platformanyň uzynlygyna okunyň merkezinde ýerleşdirilmeli, '
      'sag we çep ýapyşyklaryň tapawudy 40 mm-den geçmeli däl (34-nji madda). '
      'Bu talap ekrandaky şematik ýerleşişe garamazdan üýtgemeýär.';
  static const schematicStatusEngineeringLabel = 'Inžener-tehniki barlag';

  // ---- Handbook rule/method browsing ----
  static String approvedMethodTitle(int? methodNumber, String description) =>
      methodNumber == null
          ? description
          : '$methodNumber-nji tassyklanan usul: $description';

  // ---- Five-step loading flow ----
  // The flow the customer brief (HGM.pptx) describes and the plates in
  // Berl/ illustrate: how many wagons -> which vehicles and how many ->
  // which wagon type -> place them -> secure them.
  static const breadcrumbWagons = 'Wagonlar';
  static const breadcrumbTehnika = 'Tehnika';
  static const breadcrumbWagonType = 'Wagon görnüşi';
  static const breadcrumbPlacement = 'Ýerleşdirme';
  static const breadcrumbEquipment = 'Enjamlar';
  static const breadcrumbFastening = 'Berkitme';

  // ---- Step 1: how many wagons ----
  static const consistSetupTitle = 'WAGONLARYŇ SANYNY KESGITLE';
  static const consistSetupSubtitle =
      'Ýüklenjek düzüme näçe wagon gerekdigini saýlaň. Wagonyň görnüşi '
      'üçünji ädimde saýlanýar.';
  static const consistWagonCountLabel = 'Wagonlaryň sany';
  static const consistAddWagon = 'Wagon goş';
  static const consistRemoveWagon = 'Wagon aýyr';
  static const consistSpinHint =
      'Tegelegi aýlaň — her aýlanyşda wagon sany bir köpelýär. Gerekli '
      'sana ýetende duruzyň.';
  static const consistSpinStart = 'Aýlat';
  static const consistSpinStop = 'Duruz';
  static const consistNextButton = 'Indiki — tehnika saýla';
  static String consistWagonCountValue(int count) => '$count wagon';
  static const consistNoWagonsYet = 'Entek wagon saýlanmadyk';

  // ---- Step 2: which vehicles, how many ----
  static const vehicleOrderTitle = 'ÝÜKLENJEK TEHNIKANY SAÝLA';
  static const vehicleOrderSubtitle =
      'Tehnikanyň üstüne her gezek basanyňyzda sany bir köpelýär.';
  static const vehicleOrderAdd = 'Goş';
  static const vehicleOrderRemove = 'Aýyr';
  static const vehicleOrderSummaryTitle = 'JEMI SAÝLANAN TEHNIKA';
  static const vehicleOrderEmpty = 'Entek tehnika saýlanmadyk';

  /// The same total as a readout's label, with the number read off the value
  /// column beside it rather than spliced into a sentence.
  static const vehicleOrderTotalLabel = 'Jemi';
  static const vehicleOrderNextButton = 'Indiki — wagon görnüşi';

  // ---- Step 3: which wagon type ----
  static const wagonTypeTitle = 'WAGONYŇ GÖRNÜŞINI SAÝLA';
  static const wagonTypeSubtitle =
      'Saýlanan görnüş düzümdäki ähli wagonlara ulanylýar.';
  static const wagonTypeNoneAvailable =
      'Saýlanan tehnika üçin laýyk wagon görnüşi tapylmady.';

  // ---- Step 4: placement ----
  static const placementTitle = 'TEHNIKANY WAGONA ÝERLEŞDIR';
  static const placementSubtitle =
      'Tehnikany saýlap wagona goýuň. Bir wagonyň üstünde birnäçe tehnika '
      'bolup biler.';
  static const placementSideViewLabel = 'GAPDALDAN GÖRNÜŞI';
  static const placementPlanViewLabel = 'ÝOKARDAN GÖRNÜŞI';
  static const placementRemaining = 'Ýerleşdirmeli galan tehnika';
  static const placementAllPlaced = 'Ähli tehnika ýerleşdirildi';
  static const placementPlaceHere = 'Şu wagona goý';
  static const placementRemove = 'Aýyr';
  static const placementSpanCoupling = 'Iki wagonyň tirkeg ýerinde goý';
  static const placementSpansCouplingLabel = 'Tirkeg ýerinde';
  static const placementNextButton = 'Indiki — enjamlar';
  static const placementNothingPlaced =
      'Berkitmäge geçmek üçin azyndan bir tehnika ýerleşdirilmeli.';
  static String placementWagonLabel(int index) => '$index-nji wagon';
  static const placementEmptyWagon = 'Boş';

  // ---- Step 5: securing ----
  static const securingTitle = 'TEHNIKANY BERKIT';
  static const securingSelectPlacement =
      'Berkitmek üçin ýerleşdirilen tehnikany saýlaň.';
  static const securingToAnalysisButton = 'Inžener-tehniki analize geç';

  // ---- Three-dimensional loading view ----
  //
  // The 3D scene is a *measured* drawing: it is built from the vehicle's and
  // the wagon's real dimensions, so the figures it reports below the picture
  // are readings off a model, not decorations. The strings here therefore
  // keep two things apart at all times — what the model measures, and what
  // the handbook rules. The view states the first and never asserts the
  // second.
  static const scene3dTitle = 'ÜÇ ÖLÇEGLI GÖRNÜŞ';
  static const scene3dResetView = 'Görnüşi dikelt';
  static const scene3dPositionLabel = 'Wagonyň ugry boýunça ýerleşişi';
  static const scene3dTurretLabel = 'Diňiň ugry';
  static const scene3dTurretForward = 'Öňe';
  static const scene3dTurretRear = 'Yza';
  static const scene3dShowLashings = 'Sim çekmeler';
  static const scene3dShowTrackBed = 'Demir ýol';
  static const scene3dShowEdges = 'Gyra çyzyklary';

  // Readouts under the scene.
  static const scene3dMeasurementsHeading = 'MODELDEN ALNAN ÖLÇEGLER';
  static const scene3dLoadHeightLabel = 'Relsden ýüküň umumy beýikligi';
  static const scene3dDeckHeightLabel = 'Relsden palubanyň beýikligi';
  static const scene3dFrontOverhangLabel = 'Öňdäki çykyp durmagy';
  static const scene3dRearOverhangLabel = 'Yzdaky çykyp durmagy';
  static const scene3dLateralOverhangLabel = 'Gapdaldan çykyp durmagy (her tarapdan)';
  // Measured off the drawn solid — the whole machine, gun and stowage
  // included — which is not the same as the deck budget's figure. The budget
  // charges the recorded hull length, so on a tank with the gun forward the
  // two differ by the overhang, and the label says which this one is.
  static const scene3dFreeDeckLabel = 'Boş paluba (ähli çykyntylar bilen)';
  static const scene3dLoadWidthLabel = 'Ýüküň umumy ini';
  static const scene3dNone = 'Ýok';
  static String scene3dMetres(double metres) => '${metres.toStringAsFixed(2)} m';

  // What the readouts are and are not.
  static const scene3dMeasurementNote =
      'Bu sanlar modeliň özünden alnan ölçegler — netije ýa-da rugsat däl. Çykarylan '
      'gollanma maglumatlarynda ýüküň gabarasy (габарит) baradaky tablisa ýok, '
      'şonuň üçin bu görnüş ölçegi görkezýär, emma onuň kada laýykdygyny aýtmaýar.';
  static const scene3dLashingIndicativeNote =
      'Sim çekmeleriň sany bu tehnika üçin çykarylan maglumatlarda kesgitlenmedik — '
      'surattaky simleriň sany diňe berkitmegiň ýoluny görkezýär. (Sim çekmeleriň sany '
      '55-nji bentde diňe tigirli tehnika üçin berlen.)';
  static String scene3dLashingStrandsResolved(int strands) =>
      'Her sim çekmede $strands sapak — söweş agramy boýunça, 1-nji jedwel (plate-03).';
  static const scene3dLashingEyeNote =
      'Sim çekmeleriň tehnika birleşýän nokatlary — şertli: çykarylan maglumatlarda '
      'hiç bir tehnika üçin berkitme halkalarynyň sany ýok.';
  static String scene3dOverhangWarning(String designation) =>
      '$designation wagonyň palubasyndan daşary çykyp dur — ýerleşişini ýa-da diňiň '
      'ugruny üýtgediň.';
  static const scene3dWagonDefaultGeometryNote =
      'Wagon — standart dört oklukly açyk platforma (13,30 × 2,87 m, palubasy 1,31 m). '
      'Çykarylan gollanma maglumatlarynda wagonyň ölçegleri ýok, şonuň üçin bu ölçegler '
      'gollanmadan däl.';
  // A model file is somebody else's work, redistributed under terms that
  // require their name to travel with it — and a reader is owed the difference
  // between a model a person made and a shape this application derived from a
  // table of dimensions.
  static String scene3dModelCredit(String credit) =>
      'Tehnikanyň üç ölçegli modeli daşarky çeşmeden: $credit. Modeliň ölçegleri '
      'ýazgydaky ölçeglere görä deň gatnaşykda ulaldyldy — ölçegler modelden däl-de, '
      'ýazgydan alynýar.';
  static const scene3dWagonMeasuredGeometryNote =
      'Wagonyň ölçegleri saýlanan platformanyň ýazgysyndan alyndy.';

  // ---- Provenance of a manufacturer-specified vehicle ----
  static const dataSourceManufacturerBadge = 'ÖNDÜRIJINIŇ MAGLUMATY';
  static const dataSourceManufacturerTooltip =
      'Bu tehnikanyň san maglumatlary öndürijiniň resmi häsiýetnamasyndan alyndy. '
      'Gollanmanyň 14-nji goşundysynyň sanawynda bu tehnika ady bilen agzalmaýar, '
      'şonuň üçin onuň berkidiliş usuly gollanmadan gönümel çykarylyp bilinmeýär.';

  /// The vehicle transport-characteristics table — the ministry document that
  /// states a length, width, height and weight for each vehicle the unit
  /// moves. It decides which vehicles this trainer offers; it assigns no
  /// securing hardware, and a record that carries none says so.
  static const dataSourceTransportTableBadge = 'ULAG HÄSIÝETNAMALARY';
  static const dataSourceTransportTableTooltip =
      'Ölçegler «Harby tehnikalaryň ulag häsiýetnamalary» tablisasyndan alyndy. '
      'Ol tablisa berkitme usulyny kesgitlemeýär — berkitme diňe gollanmanyň '
      '14-nji goşundysyndaky 11-nji we 13-nji tablisalar boýunça bellenýär.';

  // ---- Who is sitting the attempt ----
  //
  // The trainer is used as a test, and an instructor gets a result sheet back
  // that has to say whose it is. So the name is asked for before the attempt
  // starts rather than offered as an optional field afterwards, and the
  // attempt cannot begin without both halves of it.
  static const traineeDialogTitle = 'DIŇLEÝJINIŇ MAGLUMATLARY';
  static const traineeDialogIntro =
      'Synag başlamazdan öň adyňyzy we familiýaňyzy giriziň. Bu maglumatlar '
      'netije hasabatynda (PDF) görkeziler.';
  static const traineeGivenNameLabel = 'Ady';
  static const traineeFamilyNameLabel = 'Familiýasy';
  static const traineeGivenNameHint = 'Meselem: Aman';
  static const traineeFamilyNameHint = 'Meselem: Amanow';
  static const traineeBeginButton = 'Synaga başla';
  static const traineeCancelButton = 'Ýatyr';
  static const traineeIncompleteNote =
      'Ady we familiýasy hem doldurylmaly.';
  static String traineeLabel(String name) => 'Diňleýji: $name';
  static const traineeUnknown = 'Diňleýji görkezilmedik';

  // ---- Clearance between two vehicles on one wagon ----
  //
  // The plates dimension it — 100 mm between two tracked vehicles on one
  // flatcar, 50 mm between wheeled ones in a row, 270 mm for a mixed pair —
  // and until the scene could draw both vehicles there was no way to find out
  // whether a load had it.
  static const placementClearanceCheckLabel =
      'Bir wagondaky tehnikalaryň arasyndaky aralyk';
  static const placementClearanceUnknownDetail =
      'Bu jübüt üçin çykarylan gollanma maglumatlarynda iň az aralyk görkezilmedik.';
  static String placementClearanceOkDetail(
          String rear, String front, double gapMm, int requiredMm) =>
      '$rear bilen $front-yň arasy ${gapMm.toStringAsFixed(0)} mm — talap edilýän '
      '$requiredMm mm-den az däl.';
  static String placementClearanceTooCloseDetail(
          String rear, String front, double gapMm, int requiredMm) =>
      '$rear bilen $front-yň arasy diňe ${gapMm.toStringAsFixed(0)} mm — '
      'talap edilýän $requiredMm mm-den az.';
  static String placementClearanceOverlapDetail(
          String rear, String front, double overlapMm) =>
      '$rear bilen $front biri-birine ${overlapMm.toStringAsFixed(0)} mm girýär. '
      'Top öňe gönükdirilen bolsa, ony yza öwrüp görüň.';
  static const scene3dGapLabel = 'Tehnikalaryň arasy';
  static String scene3dGapRequired(int mm) => 'talap: ≥ $mm mm';

  // ---- Where each block ended up, against where it should have been ----
  static const reportSeatingHeading = 'DURUZYJYLARYŇ ÝERLEŞIŞI';
  static const reportSeatingPiece = 'Serişde';
  static const reportSeatingVehicle = 'Tehnika';
  static const reportSeatingMeasured = 'Goýlan (sm)';
  static const reportSeatingRequired = 'Kada boýunça (sm)';
  static const reportSeatingError = 'Tapawut (sm)';
  static const reportSeatingNoRange = 'Kesgitlenmedik';
  static const reportSeatingNotUnderRun = 'Gusenisanyň aşagynda däl';
  static const reportSeatingWrongWay = 'Ters goýlan';
  static const reportSeatingNone =
      'Ýerleşdirilen duruzyjy ýok — üç ölçegli görnüşde hiç bir duruzyjy '
      'goýulmady ýa-da olaryň ölçegi kesgitlenmedi.';
  static String reportSeatingRange(int minCm, int maxCm) => '$minCm-$maxCm';
  static String reportSeatingOffBy(double cm) =>
      cm == 0 ? '0' : (cm > 0 ? '+${cm.toStringAsFixed(1)}' : cm.toStringAsFixed(1));

  // ---- Finishing an attempt ----
  static const finishAttemptButton = 'Synagy tamamla we täzeden başla';
  static const finishAttemptDialogTitle = 'SYNAGY TAMAMLAMAK';
  static const finishAttemptDialogBody =
      'Synag tamamlanýar we ähli saýlananlar arassalanýar: tehnikalar, wagonlar, '
      'berkidiş serişdeleri we diňleýjiniň ady. Şondan soň täze synag tehnika '
      'saýlamakdan başlanýar. Hasabaty PDF görnüşinde ýatda saklan bolsaňyz, ol '
      'faýl saklanyp galýar.';
  static const finishAttemptConfirm = 'Hawa, tamamla';

  // ---- Ground pressure, computed rather than deferred ----
  //
  // The para. 51 limit is a pressure, and a pressure is a weight over an
  // area. The area is the vehicle's own: both track shoes, over the length of
  // track bearing on the ground. Both figures are recorded fields, so the
  // check states its working — a trainee told a load fails a limit is owed the
  // arithmetic that reached it.

  // ---- The 15 t special case for side-ramp loading (para. 51) ----

  // ---- Placing the securing gear by hand in the three-dimensional view ----
  //
  // The plates dimension one thing about a stop block: how far its working
  // face stands off the running gear. Now that the scene is built from real
  // metres, that distance can be measured on a block the trainee has placed
  // themselves — so these strings report a measurement and, where the chosen
  // arrangement states a range, a check against that range with its own
  // citation. Where no range is recorded the answer is "not determined",
  // never a guess.
  static const seatingDistanceCheckLabel = 'Duruzyjynyň gusenisadan aralygy';
  static const seatingDistanceUnknownDetail =
      'Saýlanan ýerleşdiriş usuly üçin çykarylan gollanma maglumatlarynda '
      'duruzyjynyň gusenisadan aralygy görkezilmedik — bu aralyk ölçelýär, '
      'emma kada laýykdygy barlanyp bilinmeýär.';
  static String seatingDistanceOkDetail(double cm, int minCm, int maxCm) =>
      'Duruzyjy gusenisadan ${cm.toStringAsFixed(1)} sm aralykda — kada laýyk '
      '($minCm-$maxCm sm).';
  static String seatingDistanceOutOfRangeDetail(double cm, int minCm, int maxCm) =>
      'Duruzyjy gusenisadan ${cm.toStringAsFixed(1)} sm aralykda — kada laýyk däl, '
      '$minCm-$maxCm sm bolmaly.';
  static String seatingDistanceNotUnderRunDetail(double offsetCm) =>
      'Duruzyjy gusenisanyň aşagynda däl: merkezinden ${offsetCm.toStringAsFixed(0)} sm '
      'gyşarypdyr. Duruzyjy gusenisanyň öňünde ýa-da yzynda, onuň giňligine '
      'gabat goýulmaly.';
  static const seatingDistanceOtherHardwareDetail =
      'Gusenisadan aralygy ölçeldi. Emma 10-15 sm çägi agaç duruzyjy üçin ýazylan — '
      'KGUUB gysgyjynyň, demir şporyň we demir başmagyň öz aýratyn kadalary bar, '
      'şonuň üçin bu bölek şol çäk boýunça bahalandyrylmaýar.';
  static const seatingDistanceWrongWayDetail =
      'Duruzyjy ters goýlupdyr: onuň dik ýüzi gusenisa tarap seretmeli, '
      'ýapgyt tarapy däl.';

  // ---- Admin panel -------------------------------------------------------

  static const adminTitle = 'DOLANDYRYŞ PANELI';
  static const adminSubtitle =
      'Gollanmada ýok tehnikany we wagony goşmak, suratlaryny bermek';
  static const adminVehiclesHeading = 'GOŞULAN TEHNIKA';
  static const adminWagonsHeading = 'GOŞULAN WAGONLAR';
  static const adminNothingAdded = 'Heniz hiç zat goşulmady.';
  static const adminAddVehicle = 'Tehnika goş';
  static const adminAddWagon = 'Wagon goş';
  static const adminSaveButton = 'Ýatda sakla';
  static const adminRemove = 'Aýyr';
  static const adminPhotosButton = 'Suratlar';

  static const adminFieldDesignation = 'Ady (bellenişi)';
  static const adminFieldCategory = 'Görnüşi';
  static const adminFieldLength = 'Uzynlygy (sm)';
  static const adminFieldWidth = 'Ini (sm)';
  static const adminFieldHeight = 'Beýikligi (sm)';
  static const adminFieldWeight = 'Agramy (t)';
  static const adminFieldClearance = 'Kliring (sm)';
  static const adminFieldTrackWidth = 'Gusenisanyň ini (mm)';
  static const adminFieldAxles = 'Oklaryň sany';
  static const adminFieldWagonName = 'Wagonyň ady';
  static const adminFieldDeckHeight = 'Polunyň beýikligi (sm)';
  static const adminFieldTieDownRings = 'Halkalaryň sany';

  static const adminCatalogueHeading = 'GOLLANMADAKY TEHNIKANYŇ SURATLARY';
  static const adminCatalogueIntro =
      'Programma bilen gelen tehnikanyň suratyny hem çalşyp bilersiňiz. Öz '
      'suratyňyz goşulsa, programmanyň öz suraty görkezilmeýär.';
  static const adminCatalogueSearch = 'Tehnikanyň adyny ýazyň';
  static const adminCatalogueHint =
      'Gözlemek üçin adyny ýazyň — meselem "T-72" ýa-da "BTR".';
  static const adminCatalogueNoMatch = 'Beýle atly tehnika tapylmady.';
  static const adminCatalogueShipped = 'programmanyň öz suraty';
  static const adminCatalogueReplaced = 'öz suratyňyz bilen çalşyldy';

  static const adminGearHeading = 'ENJAMLARYŇ SURATLARY';
  static const adminGearIntro =
      'Her enjamyň suratyny goşup ýa-da çalşyp bilersiňiz. Goşulan surat '
      'gollanmadaky surata derek görkezilýär.';
  static const adminGearNoPhoto = 'surat goşulmadyk — gollanmanyň suraty görkezilýär';
  static const adminGearHasPhoto = 'öz suratyňyz goşuldy';

  static const adminPhotosTitle = 'Tehnikanyň suratlary';
  static const adminPhotosIntro =
      'Her tarapdan bir surat: öňünden, gapdalyndan we yzyndan. Suratyň doly '
      'ýoluny ýazyň — surat göçürilip programmanyň öz bukjasyna salynýar.';
  static String adminPhotoView(String view) => switch (view) {
        'front' => 'Öňünden',
        'side' => 'Gapdalyndan',
        _ => 'Yzyndan',
      };
  static const adminPhotoAttach = 'Goş';
  static String adminPhotoNotFound(String path) =>
      'Şeýle atly surat tapylmady: $path';

  // ---- What was actually laid on the wagon ------------------------------
  //
  // Counts and seating, both marked. The trainee is told which kind is short
  // or over and by how many, and which blocks are not where the plate puts
  // them — a mark with no reading behind it teaches nothing.

  /// One piece of securing gear, named the way the palette names it.
  static String pieceKindName(SecuringPieceKind kind) => switch (kind) {
        SecuringPieceKind.woodChock => 'agaç duruzyjy',
        SecuringPieceKind.woodInsert => 'ara goýulýan ýarym tegelek agaç',
        SecuringPieceKind.woodPacking => 'ara goýulýan agaç',
        SecuringPieceKind.woodSideBlock => 'gapdal agaç bölegi',
        SecuringPieceKind.staple => 'demir skoba',
        SecuringPieceKind.ironChock => 'KGUUB duruzyjy',
        SecuringPieceKind.ironSpur => 'demir şpor',
        SecuringPieceKind.ironChockBoot => 'demir basmak',
        SecuringPieceKind.wireLashing => 'sim bogaw',
      };

  /// A placed piece named the way a person reads it.
  ///
  /// The layout numbers pieces `woodChock-1`, which is the right key for the
  /// code and the wrong thing to print on a sheet an instructor hands to a
  /// soldier. Falls back to the raw id if it is not in the expected shape.
  static String pieceLabel(String pieceId) {
    final cut = pieceId.lastIndexOf('-');
    if (cut <= 0) return pieceId;
    final name = pieceId.substring(0, cut);
    final number = pieceId.substring(cut + 1);
    for (final kind in SecuringPieceKind.values) {
      if (kind.name == name) return '${pieceKindName(kind)} $number';
    }
    return pieceId;
  }

  static String pieceCountCheckLabel(String piece) => '$piece sany';
  static String pieceCountOkDetail(String piece, int required) =>
      'Talap edilýän $required sany $piece goýlupdyr.';
  static String pieceCountTooFewDetail(String piece, int placed, int required) =>
      '$placed sany $piece goýlupdyr, $required sany bolmaly — '
      '${required - placed} sany kem.';
  static String pieceCountTooManyDetail(String piece, int placed, int required) =>
      '$placed sany $piece goýlupdyr, $required sany bolmaly — '
      '${placed - required} sany artyk.';

  static const seatingConformanceLabel = 'Duruzyjylaryň ýerleşişi';
  static String seatingConformanceOkDetail(int judged) =>
      'Barlanan $judged duruzyjynyň hemmesi kada laýyk ýerleşdirilipdir.';
  static String seatingConformanceWrongDetail(
          int wrong, int judged, String faults) =>
      'Barlanan $judged duruzyjydan $wrong sanysy nädogry ýerleşdirilipdir: '
      '$faults.';
  static String seatingFaultBesideRun(String pieceId) =>
      '$pieceId gusenisanyň aşagynda däl';
  static String seatingFaultWrongWay(String pieceId) => '$pieceId ters goýlupdyr';
  static String seatingFaultOutOfRange(
          String pieceId, double cm, int minCm, int maxCm) =>
      '$pieceId ${cm.toStringAsFixed(1)} sm ($minCm-$maxCm sm bolmaly)';
  static String seatingFaultOff(String pieceId, double cm) =>
      '$pieceId ${cm.toStringAsFixed(1)} sm';

  static const conformanceChecksHeading = 'GOÝLAN ENJAMLAR BOÝUNÇA BARLAGLAR';

  /// The result sheet's section for the counts.
  static const pieceCountsHeading = 'ENJAMLARYŇ SANY';
  static const pieceCountColumnKind = 'Enjam';
  static const pieceCountColumnRequired = 'Talap';
  static const pieceCountColumnPlaced = 'Goýlan';

  // ---- Iron spurs (demir şpor) -------------------------------------------
  //
  // Four spurs to a set, one at each end of each track. The type is Table 13's
  // answer for the vehicle, not a weight bracket, so the wording says which
  // vehicle the type belongs to rather than which weight it covers.

  static const spurStationLeftRear = 'çep gusenisa, yzky ujy';
  static const spurStationLeftFront = 'çep gusenisa, öňki ujy';
  static const spurStationRightRear = 'sag gusenisa, yzky ujy';
  static const spurStationRightFront = 'sag gusenisa, öňki ujy';

  static const spurApplicabilityLabel = 'Demir şpor bu tehnika degişlimi';
  static const spurTypeCheckLabel = 'Demir şporuň görnüşi';
  static const spurCountCheckLabel = 'Demir şporlaryň sany';
  static const spurStationsCheckLabel = 'Demir şporlaryň ýerleşişi';

  static const spurNotPermittedDetail =
      'Bu tehnika 13-nji tablisada demir şpor bilen berkidilýänleriň hataryna '
      'girizilmedik, ýöne şpor goýlupdyr. Demir şpor diňe tablisada ady '
      'agzalan tehnika üçin; beýlekiler KGUUB, agaç duruzyjy ýa-da demir '
      'basmak bilen berkidilýär.';

  static String spurTypeOkDetail(String type) =>
      '13-nji tablisa boýunça bu tehnika üçin $type görnüşli demir şpor talap '
      'edilýär we şol görnüş goýlupdyr.';
  static String spurTypeNotStatedDetail(String type) =>
      '13-nji tablisa boýunça bu tehnika üçin $type görnüşli demir şpor talap '
      'edilýär. Goýlan şporlaryň görnüşi görkezilmändir, şonuň üçin deňeşdirip '
      'bolmaýar.';
  static String spurWrongTypeDetail(String station, String placed, String required) =>
      '$station: $placed görnüşli şpor goýlupdyr, 13-nji tablisa boýunça '
      '$required bolmaly.';

  static String spurCountOkDetail(int required) =>
      'Bir toplum $required şpor — şonça hem goýlupdyr.';
  static String spurCountWrongDetail(int placed, int required) =>
      '$placed şpor goýlupdyr. Bir toplum $required şpor: her gusenisanyň iki '
      'ujuna birden (10-njy tablisa toplumyň agramyny $required şpor üçin '
      'görkezýär).';

  static const spurStationsOkDetail =
      'Dört şporuň hemmesi öz ýerinde: her gusenisanyň öňki we yzky ujunda '
      'birden, gusenisanyň aşagynda we dişi tehnika tarap.';
  static String spurStationsWrongDetail(String stations) =>
      'Ýalňyş ýerler: $stations.';

  /// The placement could not be modelled, so no spur's seat was measured at
  /// all. Reported as undecided rather than as four correct stations.
  static const spurStationsNotMeasuredDetail =
      'Şporlaryň ýerleşişi ölçenilmedi: bu tehnikanyň ölçegleri ýazgyda ýok, '
      'şonuň üçin gusenisalaryň uçlaryna görä ýer kesgitlenip bilinmeýär '
      '(31-nji bent).';

  static String spurMissingDetail(String station) =>
      '$station: şpor goýulmandyr.';
  static String spurDoubledDetail(String station) =>
      '$station: bir ýere birnäçe şpor goýlupdyr, başga bir uç bolsa boş '
      'galypdyr.';
  static String spurBesideTrackDetail(String station) =>
      '$station: şpor gusenisanyň aşagynda däl, gapdalynda. Dişi gusenisa '
      'degmese, şpor hiç zady saklamaýar.';
  static String spurWrongWayDetail(String station) =>
      '$station: şpor ters goýlupdyr — dişi tehnika tarap seretmeli.';
  static String spurOverlappingDetail(String station) =>
      '$station: şpor gusenisanyň ujunda däl, onuň aşagyna girip dur. Şpor '
      'gusenisanyň ujuna, ýöremegine böwet bolar ýaly goýulmaly.';

  static const spurChecksHeading = 'DEMIR ŞPOR BOÝUNÇA BARLAGLAR';

  /// The result sheet's section for the four spur stations.
  static const spurFindingsHeading = 'DEMIR ŞPORLARYŇ ÝERLEŞIŞI';
  static const spurColumnStation = 'Ýeri';
  static const spurColumnPlaced = 'Goýlan';
  static const spurColumnVerdict = 'Netije';
  static const spurStationEmpty = 'ýok';

  // The editing controls.
  static const scene3dEditHeading = 'BERKITME SERIŞDELERINI ÝERLEŞDIRMEK';
  static const scene3dDragHint =
      'Serişdäniň üstüne basyp saýlaň, soň çekip süýşüriň. Boş ýerden çekseňiz '
      'görnüş aýlanýar. Duruzyjyny gusenisanyň öňüne ýa-da yzyna — nirä gerek '
      'bolsa şol ýere goýup bilersiňiz.';
  static const scene3dRemoveSelected = 'Saýlanany aýyr';
  static const scene3dResetLayout = 'Ählisini aýyr';
  static const scene3dFlipFacing = 'Ugruny öwür';
  static const scene3dSnapToRun = 'Gusenisa gysdyr';
  static const scene3dShowGuides = 'Gusenisanyň çyzyklary';

  // What is selected, and how it sits.
  // ---- Placing to the centimetre ----
  //
  // Dragging through a perspective view is fine for getting a piece roughly
  // where it belongs and hopeless for getting it exactly there: a centimetre
  // on the deck is a pixel or two on the screen. The plate dimensions the
  // seating distance in centimetres, so the trainee is given centimetres —
  // typed, or stepped one at a time.
  // Chosen before the piece goes down, because that is the order the job is
  // done in: pick the block, know the distance, then set it.
  static const scene3dPlaceAtLabel = 'Gusenisadan aralygy (sm):';
  static const scene3dPlaceAtWheelLabel = 'Tigirden aralygy (sm):';
  static const scene3dPlaceAtHint = 'meselem 12';
  static String scene3dPlaceAtRange(int minCm, int maxCm) =>
      'Saýlanan usul boýunça $minCm-$maxCm sm';
  static const scene3dPlaceAtNoRange =
      'Ýerleşdiriş usuly saýlanmady — aralyk gollanmadan görkezilmeýär.';
  static const scene3dEmptyDeckHint =
      'Paluba boş. Serişdäni saýlaň, gusenisadan näçe santimetr aralykda '
      'goýuljakdygyny giriziň we "Wagona goý" düwmesine basyň. Şondan soň ony '
      'çekip ýa-da santimetr düwmeleri bilen takyklap bilersiňiz.';

  static const scene3dPreciseHeading = 'SANTIMETR BOÝUNÇA DEŇLEŞDIRMEK';
  static const scene3dSeatingEntryLabel = 'Gusenisadan aralygy (sm)';
  static const scene3dLateralEntryLabel = 'Gusenisanyň merkezinden (sm)';
  static const scene3dAlongEntryLabel = 'Wagonyň ortasyndan (sm)';
  static const scene3dApplyButton = 'Goý';
  static String scene3dSetToTarget(int minCm, int maxCm) =>
      'Kada laýyk goý ($minCm-$maxCm sm)';
  static const scene3dShowVehicle = 'Tehnikany görkez';
  static const scene3dCentreOnRun = 'Gusenisanyň merkezine goý';
  static const scene3dVehicleHiddenNote =
      'Tehnika wagtlaýyn gizlendi — onuň aşagyndaky serişdeleri görmek we '
      'ýerleşdirmek üçin. Ölçegler üýtgemeýär: olar tehnika duran ýerinden alynýar.';

  static const scene3dSelectedHeading = 'SAÝLANAN SERIŞDE';
  static const scene3dNothingSelected =
      'Serişde saýlanmadyk — üstüne basyp saýlaň.';
  static const scene3dSeatingDistanceLabel = 'Gusenisadan aralygy';
  // A lorry bears on its tyres, and plate-06 puts a chock under each one, so
  // the figure that matters is the distance from the wheel it is against —
  // and which wheel that is.
  static const scene3dWheelDistanceLabel = 'Tigirden aralygy';
  static String scene3dAxleLabel(int number) => '$number-nji ok';
  static String scene3dSeatingEntryLabelForWheel(int number) =>
      'Tigirden aralygy — $number-nji ok (sm)';
  static const scene3dLateralOffsetLabel = 'Gusenisanyň merkezinden gyşarmasy';
  static const scene3dBlockSizeLabel = 'Ölçegi (beýikligi × ini)';
  static const scene3dBlockPositionLabel = 'Wagonyň ortasyndan aralygy';
  static const scene3dNotUnderRun = 'Gusenisanyň aşagynda däl';
  static String scene3dCentimetres(double cm) => '${cm.toStringAsFixed(1)} sm';
  // "Berkidiş bölegi" — a securing piece — rather than "duruzyjy", which is
  // specifically a stop block: the count covers the half-round inserts and the
  // packing boards too, and neither of those is a stop block.
  static String scene3dPieceCount(int pieces, int lashings) =>
      '$pieces berkidiş bölegi, $lashings sim çekme';

  static String scene3dPieceKindLabel(String kindName) {
    switch (kindName) {
      case 'woodChock':
        return 'Agaç duruzyjy';
      case 'woodInsert':
        return 'Ýarym tegelek goýum';
      case 'woodPacking':
        return 'Ara goýulýan agaç';
      case 'woodSideBlock':
        return 'Gapdal agaç blok';
      case 'staple':
        return 'Demir skoba';
      case 'ironChock':
        return 'KGUUB gysgyç';
      case 'ironSpur':
        return 'Demir şpor';
      case 'ironChockBoot':
        return 'Demir başmak';
      case 'wireLashing':
        return 'Sim çekme';
      default:
        return kindName;
    }
  }

  // ---- The palette of everything that can be put on the wagon ----
  //
  // One list rather than a button per kind: the handbook offers eleven iron
  // spurs, four stop-boots, two KGUUB variants and three stop-block weight
  // brackets, and a row of buttons could not carry any of that. Each entry
  // names the piece, the table row it came from and the size that row gives —
  // and nothing without a stated size is in the list at all.
  static const scene3dHardwareLabel = 'Goýuljak serişde:';
  static const scene3dAddSelected = 'Wagona goý';
  static const scene3dHardwareEmpty =
      'Çykarylan gollanma maglumatlarynda bu tehnika üçin ölçegi görkezilen '
      'berkidiş serişdesi ýok, şonuň üçin goýup boljak serişde-de ýok.';
  static String scene3dHardwareOption(String kind, String typeCode) =>
      '$kind — $typeCode';
  static const scene3dHardwareMatchesVehicle = ' şu tehnika üçin';

  /// The handbook's own figures for the piece the trainee is about to place —
  /// the iron spurs, the chock-boots, the reusable universal chocks. A name and
  /// a size do not tell someone who has never held one what it looks like.
  // ---- Step 5: choosing the gear ----
  //
  // The same act as ordering the vehicles, one step later in the operation:
  // look at what the handbook offers, see what each piece is, say how many the
  // load takes.
  static const equipmentSelectionTitle = 'Berkidiş enjamlaryny saýla';
  static const equipmentSelectionSubtitle =
      'Wagona goýmak üçin enjamlary we olaryň sanyny saýlaň. Ölçegler gollanmanyň '
      'tablisalaryndan alyndy; saýlamak size degişli.';
  static const equipmentNextButton = 'Indiki — berkitme';
  static const equipmentAddOne = 'Ýene bir sany goş';
  static const equipmentRemoveOne = 'Bir sanysyny aýyr';
  static const equipmentMatchesVehicle = 'Şu tehnika üçin';
  static const equipmentTallyHeading = 'Saýlanan enjamlar';
  static const equipmentTallyNote =
      'Bu ýerde saýlanan sanlar — siziň talabyňyz. Wagona hakykatda goýlanlar '
      'berkitme ädiminde görkezilýär.';
  static const equipmentTallyEmpty = 'Entek enjam saýlanmadyk.';
  static const equipmentTallyTotal = 'Jemi';

  static const scene3dHardwareFigureHeading = 'Gollanmadaky suraty';
  static const scene3dHardwareNoFigure =
      'Bu enjam üçin çykarylan gollanma bölekde surat ýok.';
  static String scene3dHardwareSize(int heightMm, int widthMm, int lengthMm) =>
      '$heightMm × $widthMm × $lengthMm mm (beýikligi × wagon ugry × ini)';

  // Choosing a block size when the vehicle's own weight resolves none.
  static const scene3dSizePickerHint =
      'Bu tehnikanyň söweş agramy 3-nji tablisanyň agram araçäklerine düşmeýär, '
      'şonuň üçin gollanma onuň üçin ölçeg bellemeýär. Ölçegi tablisanyň hakyky '
      'setirlerinden saýlaň — saýlanan setir serişdäniň ýanynda görkezilýär.';

  // ---- Result ----
  static String resultConsistSummary(int wagons, int vehicles) =>
      '$wagons wagon, $vehicles sany tehnika';
}
