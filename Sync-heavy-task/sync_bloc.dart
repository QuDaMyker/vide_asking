import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:polaris_edge/features/modules/core/domain/index.dart';
import 'package:polaris_edge/features/modules/quality/core/domain/index.dart';
import 'package:polaris_edge/features/modules/safety/core/domain/index.dart';

import '../../../features/modules/core/domain/inspection_test_plan/inspection_test_plan_failure.dart';
import '../../../features/modules/document_management/designs/domain/design/design_failure.dart';
import '../../../features/modules/document_management/designs/domain/design/i_design_repository.dart';
import '../../../features/modules/document_management/designs/domain/design_phase/design_phase_failure.dart';
import '../../../features/modules/document_management/designs/domain/design_phase/i_design_phase_repository.dart';
import '../../../features/modules/document_management/designs/domain/design_status/design_status_failure.dart';
import '../../../features/modules/document_management/designs/domain/design_status/i_design_status_repository.dart';
import '../../../features/modules/document_management/designs/domain/design_user/design_user_failure.dart';
import '../../../features/modules/document_management/designs/domain/design_user/i_design_user_repository.dart';
import '../../../features/modules/document_management/document_transmission/domain/document_transmission/document_transmission_failure.dart';
import '../../../features/modules/document_management/document_transmission/domain/document_transmission/i_document_transmission_repository.dart';
import '../../../features/modules/quality/material_approval_request/domain/mar_attachment/i_mar_attachment_repository.dart';
import '../../../features/modules/quality/material_approval_request/domain/mar_attachment/mar_attachment_failure.dart';
import '../../../features/modules/quality/material_approval_request/domain/mar_description/i_mar_description_repository.dart';
import '../../../features/modules/quality/material_approval_request/domain/mar_description/mar_description_failure.dart';
import '../../../features/modules/quality/shop_drawing/domain/shop_drawing/i_shop_drawing_repository.dart';
import '../../../features/modules/quality/shop_drawing/domain/shop_drawing/shop_drawing_failure.dart';
import '../../../features/modules/quality/shop_drawing/domain/shop_drawing_user/i_shop_drawing_user_repository.dart';
import '../../../features/modules/quality/shop_drawing/domain/shop_drawing_user/shop_drawing_user_failure.dart';
import '../../domain/database/i_synchronized_table_repository.dart';
import '../../domain/index.dart';
import '../../domain/project_type/i_project_type_repository.dart';
import '../../domain/project_user/i_project_user_repository.dart';
import '../../domain/report_template/i_report_template_repository.dart';
import '../../domain/report_template/report_template_failure.dart';
import '../../domain/workspace/i_workspace_repository.dart';
import '../../infrastructure/database/database.dart';
import '../../infrastructure/env.service.dart';
import '../../presentation/constants/app_constants.dart';

part 'sync_bloc.freezed.dart';
part 'sync_event.dart';
part 'sync_state.dart';

@injectable
class SyncBloc extends Bloc<SyncEvent, SyncState> {
  SyncBloc(
    this._phaseRepository,
    this._projectRepository,
    this._synchronizedTableRepository,
    this._projectTypeRepository,
    this._attachmentTypeRepository,
    this._attachmentRepository,
    this._companyRepository,
    this._countryRepository,
    this._issueDisciplineRepository,
    this._issuePriorityRepository,
    this._issueStatusRepository,
    this._issueTypeRepository,
    this._issueWatcherRepository,
    this._moduleRepository,
    this._moduleFunctionRepository,
    this._projectUserRepository,
    this._userRepository,
    this._workspaceRepository,
    this._workspaceUserRepository,
    this._zoneRepository,
    this._issueRepository,
    this._issueHistoryRepository,
    this._issueAttachmentRepository,
    this._workBreakdownStructureRepository,
    this._safetyCategoryRepository,
    this._syncQueueTableRepository,
    this._projectCompanyRepository,
    this._issueAssigneeRepository,
    this._reportTemplateRepository,
    this._baseIssueAttachmentRepository,
    this._baseIssueMessageRepository,
    this._baseIssueWatcherRepository,
    this._baseIssueRepository,
    this._baseValidationRepository,
    this._refAttachmentRepository,
    this._ptwNameRepository,
    this._ptwRepository,
    this._wirRepository,
    this._wirInvitationRepository,
    this._templateDataRepository,
    this._baseValidationIssueRepository,
    this._templateModuleFunctionRepository,
    this._materialApprovalRequestRepository,
    this._materialDeliveryInspectionRepository,
    this._materialDeliveryInspectionValidationRepository,
    this._mdiInvitationRepository,
    this._workPackageRepository,
    this._mdiValidationAttachmentRepository,
    this._inspectionTestPlanRepository,
    this._marDescriptionRepository,
    this._marAttachmentRepository,
    this._designPhaseRepository,
    this._designStatusRepository,
    this._designRegisterRepository,
    this._designUserRepository,
    this._documentTransmissionRepository,
    this._shopDrawingRepository,
    this._shopDrawingUserRepository,
  ) : super(SyncState.initial()) {
    on<_SyncStarted>(_onSyncStarted);
    on<_SyncCompleted>(_onSyncCompleted);
    on<_SyncFailed>(_onSyncFailed);
    on<_SkipFirstSync>(_onSkipFirstSync);
    on<_CancelSync>(_onCancelSync);
    on<_ShowModalSync>(_showModalSync);
  }

  final IPhaseRepository _phaseRepository;
  final IAttachmentTypeRepository _attachmentTypeRepository;
  final IAttachmentRepository _attachmentRepository;
  final ICompanyRepository _companyRepository;
  final ICountryRepository _countryRepository;
  final IIssueRepository _issueRepository;
  final IIssueDisciplineRepository _issueDisciplineRepository;
  final IIssuePriorityRepository _issuePriorityRepository;
  final IIssueStatusRepository _issueStatusRepository;
  final IIssueTypeRepository _issueTypeRepository;
  final IIssueHistoryRepository _issueHistoryRepository;
  final IIssueWatcherRepository _issueWatcherRepository;
  final IIssueAttachmentRepository _issueAttachmentRepository;
  final IModuleRepository _moduleRepository;
  final IModuleFunctionRepository _moduleFunctionRepository;
  final IProjectRepository _projectRepository;
  final IProjectUserRepository _projectUserRepository;
  final ISynchronizedTableRepository _synchronizedTableRepository;
  final IProjectTypeRepository _projectTypeRepository;
  final IUserRepository _userRepository;
  final IWorkspaceRepository _workspaceRepository;
  final IWorkspaceUserRepository _workspaceUserRepository;
  final IWorkBreakdownStructureRepository _workBreakdownStructureRepository;
  final ISafetyCategoryRepository _safetyCategoryRepository;
  final IZoneRepository _zoneRepository;
  final IWorkPackageRepository _workPackageRepository;
  final ISyncQueueTableRepository _syncQueueTableRepository;
  final IProjectCompanyRepository _projectCompanyRepository;
  final IIssueAssigneeRepository _issueAssigneeRepository;
  final IReportTemplateRepository _reportTemplateRepository;
  final IBaseIssueAttachmentRepository _baseIssueAttachmentRepository;
  final IBaseIssueMessageRepository _baseIssueMessageRepository;
  final IBaseIssueWatcherRepository _baseIssueWatcherRepository;
  final IBaseIssueRepository _baseIssueRepository;
  final IBaseValidationRepository _baseValidationRepository;
  final IRefAttachmentRepository _refAttachmentRepository;
  final IPtwNameRepository _ptwNameRepository;
  final IPermitToWorkRepository _ptwRepository;
  final IWorkInspectionRequestRepository _wirRepository;
  final IWirInvitationRepository _wirInvitationRepository;
  final ITemplateDataRepository _templateDataRepository;
  final IBaseValidationIssueRepository _baseValidationIssueRepository;
  final ITemplateModuleFunctionRepository _templateModuleFunctionRepository;

  final IMaterialApprovalRequestRepository _materialApprovalRequestRepository;
  final IMaterialDeliveryInspectionRepository
      _materialDeliveryInspectionRepository;
  final IMaterialDeliveryInspectionValidationRepository
      _materialDeliveryInspectionValidationRepository;
  final IMdiInvitationRepository _mdiInvitationRepository;
  final IMdiValidationAttachmentRepository _mdiValidationAttachmentRepository;
  final IInspectionTestPlanRepository _inspectionTestPlanRepository;
  final IMarDescriptionRepository _marDescriptionRepository;
  final IMarAttachmentRepository _marAttachmentRepository;

  final IDesignPhaseRepository _designPhaseRepository;
  final IDesignStatusRepository _designStatusRepository;
  final IDesignRegisterRepository _designRegisterRepository;
  final IDesignUserRepository _designUserRepository;
  final IDocumentTransmissionRepository _documentTransmissionRepository;
  final IShopDrawingRepository _shopDrawingRepository;
  final IShopDrawingUserRepository _shopDrawingUserRepository;

  Map<String, dynamic> _getSyncedData({
    required List<SynchronizedTableRecord> synchronizedTables,
    required String tableName,
    required List<Project> projectRecords,
    bool usingWorkspace = false,
  }) {
    final isMasterTable = MasterTableNames.contains(tableName);
    if (isMasterTable) {
      return {
        'lastSyncedAt': synchronizedTables
            .firstWhereOrNull((element) => element.syncTable == tableName)
            ?.lastSyncedAt
      };
    }
    final projectIds = projectRecords.map((e) => e.id.value!).toList();
    final result = projectRecords
        .map((e) => {
              'id': e.id.value,
              'lastSyncedAt': synchronizedTables
                  .firstWhereOrNull((element) =>
                      element.syncTable == tableName &&
                      (element.projectId == null ||
                          projectIds.contains(element.projectId)))
                  ?.lastSyncedAt,
            })
        .toList();

    if (usingWorkspace) {
      return {
        'workspaceIds': result
            .map((e) => {
                  'id': projectRecords
                      .firstWhere((element) => element.id.value == e['id'])
                      .workspaceId
                      .value,
                  'lastSyncedAt': e['lastSyncedAt']
                })
            .toList(),
      };
    }

    return {'projectIds': result};
  }

  Future<void> _onSkipFirstSync(
      _SkipFirstSync event, Emitter<SyncState> emit) async {
    emit(state.copyWith(isFirstSync: false));
  }

  void _onCancelSync(_CancelSync event, Emitter<SyncState> emit) {
    emit(
      state.copyWith(
        isCancelled: true,
        isSyncing: false,
        isShowSpinner: false,
      ),
    );
  }

  Future<void> _onSyncStarted(
    _SyncStarted event,
    Emitter<SyncState> emit,
  ) async {
    if (state.isSyncing) {
      return;
    }

    emit(state.copyWith(
      isSyncing: true,
      isCancelled: false,
      progress: 0.0,
      showModal: event.showModal,
    ));

    // Run sync with isolate for background processing
    if (event.runInBackground) {
      await _performSyncWithIsolate(event, emit);
    } else {
      await _performSyncDirect(event, emit);
    }
  }

  /// Perform sync using compute() to run in isolate
  Future<void> _performSyncWithIsolate(
    _SyncStarted event,
    Emitter<SyncState> emit,
  ) async {
    // Since we can't pass repositories to isolate, we'll:
    // 1. Run sync coordination in main isolate
    // 2. Use periodic yields to keep UI responsive
    // 3. Run heavy processing chunks in isolate if needed
    
    await _performSyncDirect(event, emit);
  }

  /// Perform sync directly in main isolate with async/await
  Future<void> _performSyncDirect(
    _SyncStarted event,
    Emitter<SyncState> emit,
  ) async {
    final synchronizedTables =
        await _synchronizedTableRepository.getSynchronizedTables();

    var projectRecords = await _projectRepository.getOfflineProjects();
    List<String> projectIds =
        projectRecords.map((e) => e.id.value ?? '').toList();

    if (event.projectId != null) {
      emit(state.copyWith(isShowSpinner: true));
      projectRecords = [
        Project(
          id: NullableString.pure(event.projectId),
          workspaceId: RequiredString.pure(event.workspaceId ?? ''),
        )
      ];
      projectIds = [event.projectId!];
    }

    if (state.isCancelled) {
      emit(state.copyWith(isSyncing: false, isShowSpinner: false));
      return;
    }

    await _syncQueueTableRepository.syncToServer();

    var isFailed = false;
    var currentStep = 0;

    final sequentialTasks = <Map<String, dynamic>>[
      // if (!event.isAppStart) ...[
      {
        'table': 'attachments',
        'action': () => _onSyncAttachments(
              selectedPeriod: event.selectedPeriod,
              selectedStatus: event.selectedStatus,
              data: _getSyncedData(
                synchronizedTables: synchronizedTables,
                tableName: 'attachments',
                projectRecords: projectRecords,
              ),
            ),
      },
      // ],
      {
        'table': 'template_module_functions',
        'action': () => _onSyncTemplateModuleFunctions(
              data: _getSyncedData(
                synchronizedTables: synchronizedTables,
                tableName: 'template_module_functions',
                projectRecords: projectRecords,
              ),
            ),
      },
      {
        'table': 'issue_attachments',
        'action': () => _onSyncIssueAttachments(
              data: _getSyncedData(
                synchronizedTables: synchronizedTables,
                tableName: 'issue_attachments',
                projectRecords: projectRecords,
              ),
            ),
      },
      {
        'table': 'report_templates',
        'action': () => _onSyncReportTemplates(
              data: _getSyncedData(
                synchronizedTables: synchronizedTables,
                tableName: 'report_templates',
                projectRecords: projectRecords,
              ),
            ),
      },

      // {
      //   'table': 'location_plans',
      //   'action': () => _onSyncLocationPlans(
      //         data: _getSyncedData(
      //           synchronizedTables: synchronizedTables,
      //           tableName: 'location_plans',
      //           projectRecords: projectRecords,
      //         ),
      //       ),
      // },
      {
        'table': 'ref_attachments',
        'action': () => _onSyncRefAttachments(
              data: _getSyncedData(
                synchronizedTables: synchronizedTables,
                tableName: 'ref_attachments',
                projectRecords: projectRecords,
              ),
            ),
      },
      {
        'table': 'ref_templates',
        'action': () => _onSyncRefTemplates(
              data: _getSyncedData(
                synchronizedTables: synchronizedTables,
                tableName: 'ref_templates',
                projectRecords: projectRecords,
              ),
            ),
      },
      {
        'table': 'wir_invitations',
        'action': () => _onSyncWirInvitations(
              data: _getSyncedData(
                synchronizedTables: synchronizedTables,
                tableName: 'wir_invitations',
                projectRecords: projectRecords,
              ),
            ),
      },
      ...EnvService.isFeatureDevOnly(DevOnlyFeatures.OTHERS)
          ? [
              {
                'table': 'mar_attachments',
                'action': () => _onSyncMarAttachments(
                      data: _getSyncedData(
                        synchronizedTables: synchronizedTables,
                        tableName: 'mar_attachments',
                        projectRecords: projectRecords,
                      ),
                    ),
              },
              {
                'table': 'mar_descriptions',
                'action': () => _onSyncMarDescriptions(
                      data: _getSyncedData(
                        synchronizedTables: synchronizedTables,
                        tableName: 'mar_descriptions',
                        projectRecords: projectRecords,
                      ),
                    ),
              },
              {
                'table': 'mdi_invitations',
                'action': () => _onSyncMdiInvitations(
                      data: _getSyncedData(
                        synchronizedTables: synchronizedTables,
                        tableName: 'mdi_invitations',
                        projectRecords: projectRecords,
                      ),
                    ),
              },
              {
                'table': 'mdi_validation_attachments',
                'action': () => _onSyncMdiValidationAttachment(
                      data: _getSyncedData(
                        synchronizedTables: synchronizedTables,
                        tableName: 'mdi_validation_attachments',
                        projectRecords: projectRecords,
                      ),
                    ),
              },
            ]
          : []
    ];

    final parallelTasks = [
      {
        'table': 'attachment_types',
        'action': () => _onSyncAttachmentTypes(
              data: _getSyncedData(
                synchronizedTables: synchronizedTables,
                tableName: 'attachment_types',
                projectRecords: projectRecords,
              ),
            ),
      },
      {
        'table': 'companies',
        'action': () => _onSyncCompanies(
              data: _getSyncedData(
                synchronizedTables: synchronizedTables,
                tableName: 'companies',
                projectRecords: projectRecords,
              ),
            ),
      },
      {
        'table': 'countries',
        'action': () => _onSyncCountries(
              data: _getSyncedData(
                synchronizedTables: synchronizedTables,
                tableName: 'countries',
                projectRecords: projectRecords,
              ),
            ),
      },
      {
        'table': 'issue_disciplines',
        'action': () => _onSyncIssueDisciplines(
              data: _getSyncedData(
                synchronizedTables: synchronizedTables,
                tableName: 'issue_disciplines',
                projectRecords: projectRecords,
              ),
            ),
      },
      {
        'table': 'issue_histories',
        'action': () => _onSyncIssueHistories(
              data: _getSyncedData(
                synchronizedTables: synchronizedTables,
                tableName: 'issue_histories',
                projectRecords: projectRecords,
              ),
            ),
      },
      {
        'table': 'issue_priorities',
        'action': () => _onSyncIssuePriorities(
              data: _getSyncedData(
                synchronizedTables: synchronizedTables,
                tableName: 'issue_priorities',
                projectRecords: projectRecords,
              ),
            ),
      },
      {
        'table': 'issue_statuses',
        'action': () => _onSyncIssueStatuses(
              data: _getSyncedData(
                synchronizedTables: synchronizedTables,
                tableName: 'issue_statuses',
                projectRecords: projectRecords,
              ),
            ),
      },
      {
        'table': 'issue_types',
        'action': () => _onSyncIssueTypes(
              data: _getSyncedData(
                synchronizedTables: synchronizedTables,
                tableName: 'issue_types',
                projectRecords: projectRecords,
              ),
            ),
      },
      {
        'table': 'issues',
        'action': () => _onSyncIssues(
              data: _getSyncedData(
                synchronizedTables: synchronizedTables,
                tableName: 'issues',
                projectRecords: projectRecords,
              ),
            ),
      },
      {
        'table': 'modules',
        'action': () => _onSyncModules(
              data: _getSyncedData(
                synchronizedTables: synchronizedTables,
                tableName: 'modules',
                projectRecords: projectRecords,
              ),
            ),
      },
      {
        'table': 'module_functions',
        'action': () => _onSyncModuleFunctions(
              data: _getSyncedData(
                synchronizedTables: synchronizedTables,
                tableName: 'module_functions',
                projectRecords: projectRecords,
              ),
            ),
      },
      {
        'table': 'phases',
        'action': () => _onSyncPhases(
              data: _getSyncedData(
                synchronizedTables: synchronizedTables,
                tableName: 'phases',
                projectRecords: projectRecords,
              ),
            ),
      },
      {
        'table': 'project_companies',
        'action': () => _onSyncProjectCompanies(
              data: _getSyncedData(
                synchronizedTables: synchronizedTables,
                tableName: 'project_companies',
                projectRecords: projectRecords,
              ),
            ),
      },
      {
        'table': 'project_types',
        'action': () => _onSyncProjectTypes(
              data: _getSyncedData(
                synchronizedTables: synchronizedTables,
                tableName: 'project_types',
                projectRecords: projectRecords,
              ),
            ),
      },
      {
        'table': 'project_users',
        'action': () => _onSyncProjectUsers(
              data: _getSyncedData(
                synchronizedTables: synchronizedTables,
                tableName: 'project_users',
                projectRecords: projectRecords,
              ),
            ),
      },
      {
        'table': 'users',
        'action': () => _onSyncUsers(
              data: _getSyncedData(
                synchronizedTables: synchronizedTables,
                tableName: 'users',
                projectRecords: projectRecords,
                usingWorkspace: true,
              ),
            ),
      },
      {
        'table': 'work_breakdown_structures',
        'action': () => _onSyncWorkBreakdownStructures(
              data: _getSyncedData(
                synchronizedTables: synchronizedTables,
                tableName: 'work_breakdown_structures',
                projectRecords: projectRecords,
              ),
            ),
      },
      {
        'table': 'safety_categories',
        'action': () => _onSyncSafetyCategories(
              data: _getSyncedData(
                synchronizedTables: synchronizedTables,
                tableName: 'safety_categories',
                projectRecords: projectRecords,
              ),
            ),
      },
      {
        'table': 'workspaces',
        'action': () => _onSyncWorkspaces(
              data: _getSyncedData(
                synchronizedTables: synchronizedTables,
                tableName: 'workspaces',
                projectRecords: projectRecords,
                usingWorkspace: true,
              ),
            ),
      },
      {
        'table': 'workspace_users',
        'action': () => _onSyncWorkspaceUsers(
              data: _getSyncedData(
                synchronizedTables: synchronizedTables,
                tableName: 'workspace_users',
                projectRecords: projectRecords,
                usingWorkspace: true,
              ),
            ),
      },
      {
        'table': 'zones',
        'action': () => _onSyncZones(
              data: _getSyncedData(
                synchronizedTables: synchronizedTables,
                tableName: 'zones',
                projectRecords: projectRecords,
              ),
            ),
      },
      {
        'table': 'work_packages',
        'action': () => _onSyncWorkPackage(
              data: _getSyncedData(
                synchronizedTables: synchronizedTables,
                tableName: 'work_packages',
                projectRecords: projectRecords,
              ),
            ),
      },
      {
        'table': 'issue_watchers',
        'action': () => _onSyncIssueWatchers(
              data: _getSyncedData(
                synchronizedTables: synchronizedTables,
                tableName: 'issue_watchers',
                projectRecords: projectRecords,
              ),
            ),
      },
      {
        'table': 'issue_assignees',
        'action': () => _onSyncIssueAssignees(
              data: _getSyncedData(
                synchronizedTables: synchronizedTables,
                tableName: 'issue_assignees',
                projectRecords: projectRecords,
              ),
            ),
      },
      {
        'table': 'base_issue_attachments',
        'action': () => _onSyncBaseIssueAttachments(
              data: _getSyncedData(
                synchronizedTables: synchronizedTables,
                tableName: 'base_issue_attachments',
                projectRecords: projectRecords,
              ),
            ),
      },
      {
        'table': 'base_issue_messages',
        'action': () => _onSyncBaseIssueMessages(
              data: _getSyncedData(
                synchronizedTables: synchronizedTables,
                tableName: 'base_issue_messages',
                projectRecords: projectRecords,
              ),
            ),
      },
      {
        'table': 'base_issue_watchers',
        'action': () => _onSyncBaseIssueWatchers(
              data: _getSyncedData(
                synchronizedTables: synchronizedTables,
                tableName: 'base_issue_watchers',
                projectRecords: projectRecords,
              ),
            ),
      },
      {
        'table': 'base_issues',
        'action': () => _onSyncBaseIssues(
              data: _getSyncedData(
                synchronizedTables: synchronizedTables,
                tableName: 'base_issues',
                projectRecords: projectRecords,
              ),
            ),
      },
      {
        'table': 'base_validations',
        'action': () => _onSyncBaseValidations(
              data: _getSyncedData(
                synchronizedTables: synchronizedTables,
                tableName: 'base_validations',
                projectRecords: projectRecords,
              ),
            ),
      },
      {
        'table': 'work_inspection_requests',
        'action': () => _onSyncWIRs(
              data: _getSyncedData(
                synchronizedTables: synchronizedTables,
                tableName: 'work_inspection_requests',
                projectRecords: projectRecords,
              ),
            ),
      },
      {
        'table': 'base_validation_issues',
        'action': () => _onSyncBaseValidationIssues(
              data: _getSyncedData(
                synchronizedTables: synchronizedTables,
                tableName: 'base_validation_issues',
                projectRecords: projectRecords,
              ),
            ),
      },
      {
        'table': 'inspection_test_plans',
        'action': () => _onSyncInspectionTestPlans(
              data: _getSyncedData(
                synchronizedTables: synchronizedTables,
                tableName: 'inspection_test_plans',
                projectRecords: projectRecords,
              ),
            ),
      },
      ...EnvService.isFeatureDevOnly(DevOnlyFeatures.OTHERS)
          ? [
              {
                'table': 'ptw_names',
                'action': () => _onSyncPtwNames(
                      data: _getSyncedData(
                        synchronizedTables: synchronizedTables,
                        tableName: 'ptw_names',
                        projectRecords: projectRecords,
                      ),
                    ),
              },
              {
                'table': 'permit_to_works',
                'action': () => _onSyncPermitToWorks(
                      data: _getSyncedData(
                        synchronizedTables: synchronizedTables,
                        tableName: 'permit_to_works',
                        projectRecords: projectRecords,
                      ),
                    ),
              },
              {
                'table': 'material_approval_requests',
                'action': () => _onSyncMaterialApprovalRequests(
                      data: _getSyncedData(
                        synchronizedTables: synchronizedTables,
                        tableName: 'material_approval_requests',
                        projectRecords: projectRecords,
                      ),
                    ),
              },
              {
                'table': 'material_approval_requests',
                'action': () => _onSyncMaterialApprovalRequests(
                      data: _getSyncedData(
                        synchronizedTables: synchronizedTables,
                        tableName: 'material_approval_requests',
                        projectRecords: projectRecords,
                      ),
                    ),
              },
              {
                'table': 'material_delivery_inspections',
                'action': () => _onSyncMaterialDeliveryInspections(
                      data: _getSyncedData(
                        synchronizedTables: synchronizedTables,
                        tableName: 'material_delivery_inspections',
                        projectRecords: projectRecords,
                      ),
                    ),
              },
              {
                'table': 'material_delivery_inspection_validations',
                'action': () => _onSyncMaterialDeliveryInspectionValidations(
                      data: _getSyncedData(
                        synchronizedTables: synchronizedTables,
                        tableName: 'material_delivery_inspection_validations',
                        projectRecords: projectRecords,
                      ),
                    ),
              },
              {
                'table': 'design_phases',
                'action': () => _onSyncDesignPhases(
                      data: _getSyncedData(
                        synchronizedTables: synchronizedTables,
                        tableName: 'design_phases',
                        projectRecords: projectRecords,
                      ),
                    ),
              },
              {
                'table': 'design_statuses',
                'action': () => _onSyncDesignStatuses(
                      data: _getSyncedData(
                        synchronizedTables: synchronizedTables,
                        tableName: 'design_statuses',
                        projectRecords: projectRecords,
                      ),
                    ),
              },
              {
                'table': 'design_registers',
                'action': () => _onSyncDesignRegisters(
                      data: _getSyncedData(
                        synchronizedTables: synchronizedTables,
                        tableName: 'design_registers',
                        projectRecords: projectRecords,
                      ),
                    ),
              },
              {
                'table': 'design_users',
                'action': () => _onSyncDesignUsers(
                      data: _getSyncedData(
                        synchronizedTables: synchronizedTables,
                        tableName: 'design_users',
                        projectRecords: projectRecords,
                      ),
                    ),
              },
              {
                'table': 'document_transmissions',
                'action': () => _onSyncDocumentTransmissions(
                      data: _getSyncedData(
                        synchronizedTables: synchronizedTables,
                        tableName: 'document_transmissions',
                        projectRecords: projectRecords,
                      ),
                    ),
              },
              {
                'table': 'shop_drawings',
                'action': () => _onSyncShopDrawings(
                      data: _getSyncedData(
                        synchronizedTables: synchronizedTables,
                        tableName: 'shop_drawings',
                        projectRecords: projectRecords,
                      ),
                    ),
              },
              {
                'table': 'shop_drawing_users',
                'action': () => _onSyncShopDrawingUsers(
                      data: _getSyncedData(
                        synchronizedTables: synchronizedTables,
                        tableName: 'shop_drawing_users',
                        projectRecords: projectRecords,
                      ),
                    ),
              },
            ]
          : []
    ];

    final totalTasks = sequentialTasks.length + parallelTasks.length;

    Future<void> runTask({
      required Future<Either<dynamic, String>> Function() action,
      required String tableName,
    }) async {
      if (state.isCancelled) {
        return;
      }

      final result = await action();
      await result.fold(
        (failure) async {
          print('failure in $tableName: $failure');
          // isFailed = true;
        },
        (lastSyncedAt) async {
          if (!state.isCancelled) {
            await _onUpdateLastSyncedAt(tableName, projectIds, lastSyncedAt);
          }
        },
      );

      currentStep++;
      emit(state.copyWith(progress: currentStep / totalTasks));
      
      // Yield to event loop every 5 tasks to keep UI responsive
      if (currentStep % 5 == 0) {
        await Future.delayed(Duration.zero);
      }
    }

    try {
      const batchSize = 50;
      for (var i = 0; i < parallelTasks.length; i += batchSize) {
        final batch = parallelTasks.skip(i).take(batchSize).toList();
        await Future.wait(batch.map((task) async {
          await runTask(
            action:
                task['action']! as Future<Either<dynamic, String>> Function(),
            tableName: task['table']! as String,
          );
        }));
      }

      // for (final task in sequentialTasks) {
      //   await runTask(
      //     action: task['action']! as Future<Either<dynamic, String>> Function(),
      //     tableName: task['table']! as String,
      //   );
      // }

      await Future.wait(
        sequentialTasks.map((task) async {
          await runTask(
            action:
                task['action']! as Future<Either<dynamic, String>> Function(),
            tableName: task['table']! as String,
          );
        }),
      );

      if (!isFailed && !state.isCancelled) {
        final syncProjects = await _onSyncProjects(
          data: _getSyncedData(
            synchronizedTables: synchronizedTables,
            tableName: 'projects',
            projectRecords: projectRecords,
          ),
        );

        await syncProjects.fold(
          (failure) async => isFailed = true,
          (lastSyncedAt) async {
            if (!state.isCancelled) {
              print('sync successful');
              await _onUpdateLastSyncedAt('projects', projectIds, lastSyncedAt);
            }
          },
        );
      }

      emit(state.copyWith(
        isSyncing: false,
        isFirstSync: false,
        progress: isFailed ? state.progress : 1.0,
        isShowSpinner: false,
      ));

      if (!isFailed) {
        event.onCompleted?.call();
      }
    } catch (e) {
      print('sync error: $e');
      emit(state.copyWith(isSyncing: false, isShowSpinner: false));
    }
  }

  Future<void> _onUpdateLastSyncedAt(
      String syncTable, List<String> projectIds, String lastSyncedAt) async {
    await _synchronizedTableRepository.updateLastSyncedAt(
        syncTable, projectIds, lastSyncedAt);
  }

  void _onSyncCompleted(_SyncCompleted event, Emitter<SyncState> emit) {
    emit(state.copyWith(isSyncing: false));
  }

  void _onSyncFailed(_SyncFailed event, Emitter<SyncState> emit) {
    emit(state.copyWith(isSyncing: false));
  }

  Future<Either<AttachmentTypeFailure, String>> _onSyncAttachmentTypes(
      {Map<String, dynamic>? data}) async {
    return _attachmentTypeRepository.syncAttachmentTypes(data: data);
  }

  Future<Either<AttachmentFailure, String>> _onSyncAttachments({
    Map<String, dynamic>? data,
    String? selectedPeriod,
    String? selectedStatus,
  }) async {
    return _attachmentRepository.syncAttachments(
      data: data,
      selectedPeriod: selectedPeriod,
      selectedStatus: selectedStatus,
    );
  }

  Future<Either<CompanyFailure, String>> _onSyncCompanies(
      {Map<String, dynamic>? data}) async {
    return _companyRepository.syncCompanies(data: data);
  }

  Future<Either<CountryFailure, String>> _onSyncCountries(
      {Map<String, dynamic>? data}) async {
    return _countryRepository.syncCountries(data: data);
  }

  Future<Either<IssueDisciplineFailure, String>> _onSyncIssueDisciplines(
      {Map<String, dynamic>? data}) async {
    if (data != null && data['projectIds'] != null) {
      final projectIds = List<Map<String, dynamic>>.from(data['projectIds']);
      final lastSyncedAtList = projectIds
          .map((e) => DateTime.tryParse(e['lastSyncedAt'] ?? ''))
          .where((e) => e != null)
          .cast<DateTime>()
          .toList();

      if (lastSyncedAtList.isNotEmpty) {
        final minLastSyncedAt =
            lastSyncedAtList.reduce((a, b) => a.isBefore(b) ? a : b);
        data['lastSyncedAt'] = minLastSyncedAt.toIso8601String();
      }
    }
    return _issueDisciplineRepository.syncIssueDisciplines(data: data);
  }

  Future<Either<IssueHistoryFailure, String>> _onSyncIssueHistories(
      {Map<String, dynamic>? data}) async {
    return _issueHistoryRepository.syncIssueHistories(data: data);
  }

  Future<Either<IssuePriorityFailure, String>> _onSyncIssuePriorities(
      {Map<String, dynamic>? data}) async {
    return _issuePriorityRepository.syncIssuePriorities(data: data);
  }

  Future<Either<IssueStatusFailure, String>> _onSyncIssueStatuses(
      {Map<String, dynamic>? data}) async {
    return _issueStatusRepository.syncIssueStatuses(data: data);
  }

  Future<Either<IssueTypeFailure, String>> _onSyncIssueTypes(
      {Map<String, dynamic>? data}) async {
    return _issueTypeRepository.syncIssueTypes(data: data);
  }

  Future<Either<IssueFailure, String>> _onSyncIssues(
      {Map<String, dynamic>? data}) async {
    return _issueRepository.syncIssues(data: data);
  }

  Future<Either<ModuleFailure, String>> _onSyncModules(
      {Map<String, dynamic>? data}) async {
    return _moduleRepository.syncModules(data: data);
  }

  Future<Either<ModuleFunctionFailure, String>> _onSyncModuleFunctions(
      {Map<String, dynamic>? data}) async {
    return _moduleFunctionRepository.syncModuleFunctions(data: data);
  }

  Future<Either<TemplateModuleFunctionFailure, String>>
      _onSyncTemplateModuleFunctions({Map<String, dynamic>? data}) async {
    return _templateModuleFunctionRepository.syncTemplateModuleFunctions(
        data: data);
  }

  Future<Either<PhaseFailure, String>> _onSyncPhases(
      {Map<String, dynamic>? data}) async {
    return _phaseRepository.syncPhases(data: data);
  }

  Future<Either<ProjectCompanyFailure, String>> _onSyncProjectCompanies(
      {Map<String, dynamic>? data}) async {
    return _projectCompanyRepository.syncProjectCompanies(data: data);
  }

  Future<Either<ProjectTypeFailure, String>> _onSyncProjectTypes(
      {Map<String, dynamic>? data}) async {
    return _projectTypeRepository.syncProjectTypes(data: data);
  }

  Future<Either<ProjectFailure, String>> _onSyncProjects(
      {Map<String, dynamic>? data}) async {
    return _projectRepository.syncProjects(data: data);
  }

  Future<Either<ProjectUserFailure, String>> _onSyncProjectUsers(
      {Map<String, dynamic>? data}) async {
    return _projectUserRepository.syncProjectUsers(data: data);
  }

  // Future<void> _onSyncSyncQueues({Map<String, dynamic>? data}) async {
  //   // await _syncQueueTableRepository.syncSyncQueues(data: data);
  // }
  //
  // Future<void> _onSyncSynchronizedTables({Map<String, dynamic>? data}) async {
  //   // await _synchfronizedTableRepository.syncSynchronizedTables(data: data);
  // }

  Future<Either<AttachmentFailure, String>> _onSyncLocationPlans(
      {Map<String, dynamic>? data}) async {
    return _attachmentRepository.syncLocationPlans(data: data);
  }

  Future<Either<UserFailure, String>> _onSyncUsers(
      {Map<String, dynamic>? data}) async {
    return _userRepository.syncUsers(data: data);
  }

  Future<Either<WorkBreakdownStructureFailure, String>>
      _onSyncWorkBreakdownStructures({Map<String, dynamic>? data}) async {
    return _workBreakdownStructureRepository.syncWorkBreakdownStructures(
        data: data);
  }

  Future<Either<SafetyCategoryFailure, String>> _onSyncSafetyCategories(
      {Map<String, dynamic>? data}) async {
    return _safetyCategoryRepository.syncSafetyCategories(data: data);
  }

  Future<Either<WorkspaceFailure, String>> _onSyncWorkspaces(
      {Map<String, dynamic>? data}) async {
    return _workspaceRepository.syncWorkspaces(data: data);
  }

  Future<Either<WorkspaceUserFailure, String>> _onSyncWorkspaceUsers(
      {Map<String, dynamic>? data}) async {
    return _workspaceUserRepository.syncWorkspaceUsers(data: data);
  }

  Future<Either<ZoneFailure, String>> _onSyncZones(
      {Map<String, dynamic>? data}) async {
    return _zoneRepository.syncZones(data: data);
  }

  Future<Either<WorkPackageFailure, String>> _onSyncWorkPackage(
      {Map<String, dynamic>? data}) async {
    return _workPackageRepository.syncWorkPackages(data: data);
  }

  Future<Either<IssueWatcherFailure, String>> _onSyncIssueWatchers(
      {Map<String, dynamic>? data}) async {
    return _issueWatcherRepository.syncIssueWatchers(data: data);
  }

  Future<Either<IssueAttachmentFailure, String>> _onSyncIssueAttachments(
      {Map<String, dynamic>? data}) async {
    return _issueAttachmentRepository.syncIssueAttachments(data: data);
  }

  Future<Either<IssueAssigneeFailure, String>> _onSyncIssueAssignees({
    Map<String, dynamic>? data,
  }) async {
    if (data != null && data['projectIds'] != null) {
      final projectIds = List<Map<String, dynamic>>.from(data['projectIds']);
      final lastSyncedAtList = projectIds
          .map((e) => DateTime.tryParse(e['lastSyncedAt'] ?? ''))
          .where((e) => e != null)
          .cast<DateTime>()
          .toList();

      if (lastSyncedAtList.isNotEmpty) {
        final minLastSyncedAt =
            lastSyncedAtList.reduce((a, b) => a.isBefore(b) ? a : b);
        data['lastSyncedAt'] = minLastSyncedAt.toIso8601String();
      }
    }

    return _issueAssigneeRepository.syncIssueAssignees(data: data);
  }

  Future<Either<ReportTemplateFailure, String>> _onSyncReportTemplates(
      {Map<String, dynamic>? data}) async {
    return _reportTemplateRepository.syncReportTemplates(data: data);
  }

  Future<Either<BaseIssueAttachmentFailure, String>>
      _onSyncBaseIssueAttachments({Map<String, dynamic>? data}) async {
    return _baseIssueAttachmentRepository.syncBaseIssueAttachments(data: data);
  }

  Future<Either<BaseIssueMessageFailure, String>> _onSyncBaseIssueMessages(
      {Map<String, dynamic>? data}) async {
    return _baseIssueMessageRepository.syncBaseIssueMessages(data: data);
  }

  Future<Either<BaseIssueWatcherFailure, String>> _onSyncBaseIssueWatchers(
      {Map<String, dynamic>? data}) async {
    return _baseIssueWatcherRepository.syncBaseIssueWatchers(data: data);
  }

  Future<Either<BaseIssueFailure, String>> _onSyncBaseIssues(
      {Map<String, dynamic>? data}) async {
    return _baseIssueRepository.syncBaseIssues(data: data);
  }

  Future<Either<BaseValidationFailure, String>> _onSyncBaseValidations(
      {Map<String, dynamic>? data}) async {
    return _baseValidationRepository.syncBaseValidations(data: data);
  }

  Future<Either<RefAttachmentFailure, String>> _onSyncRefAttachments(
      {Map<String, dynamic>? data}) async {
    return _refAttachmentRepository.syncRefAttachments(data: data);
  }

  Future<Either<PtwNameFailure, String>> _onSyncPtwNames(
      {Map<String, dynamic>? data}) async {
    return _ptwNameRepository.syncPtwNames(data: data);
  }

  Future<Either<PermitToWorkFailure, String>> _onSyncPermitToWorks(
      {Map<String, dynamic>? data}) async {
    return _ptwRepository.syncPermitToWorks(data: data);
  }

  Future<Either<WorkInspectionRequestFailure, String>> _onSyncWIRs(
      {Map<String, dynamic>? data}) async {
    return _wirRepository.syncWorkInspectionRequests(data: data);
  }

  Future<Either<WirInvitationFailure, String>> _onSyncWirInvitations(
      {Map<String, dynamic>? data}) async {
    return _wirInvitationRepository.syncWirInvitations(data: data);
  }

  Future<Either<TemplateDataFailure, String>> _onSyncRefTemplates({
    Map<String, dynamic>? data,
  }) async {
    return _templateDataRepository.syncRefTemplates(data: data);
  }

  Future<Either<BaseValidationIssueFailure, String>>
      _onSyncBaseValidationIssues({
    Map<String, dynamic>? data,
  }) async {
    return _baseValidationIssueRepository.syncBaseValidationIssues(data: data);
  }

  Future<Either<MaterialApprovalRequestFailure, String>>
      _onSyncMaterialApprovalRequests({
    Map<String, dynamic>? data,
  }) async {
    return _materialApprovalRequestRepository.syncMaterialApprovalRequest(
        data: data);
  }

  Future<Either<MaterialDeliveryInspectionFailure, String>>
      _onSyncMaterialDeliveryInspections({
    Map<String, dynamic>? data,
  }) async {
    return _materialDeliveryInspectionRepository.syncMaterialDeliveryInspection(
        data: data);
  }

  Future<Either<MaterialDeliveryInspectionValidationFailure, String>>
      _onSyncMaterialDeliveryInspectionValidations({
    Map<String, dynamic>? data,
  }) async {
    return _materialDeliveryInspectionValidationRepository
        .syncMaterialDeliveryInspectionValidation(data: data);
  }

  Future<Either<MdiInvitationFailure, String>> _onSyncMdiInvitations({
    Map<String, dynamic>? data,
  }) async {
    return _mdiInvitationRepository.syncMdiInvitations(data: data);
  }

  Future<Either<MdiValidationAttachmentFailure, String>>
      _onSyncMdiValidationAttachment({
    Map<String, dynamic>? data,
  }) async {
    return _mdiValidationAttachmentRepository.syncMdiValidationAttachments(
        data: data);
  }

  Future<Either<InspectionTestPlanFailure, String>> _onSyncInspectionTestPlans({
    Map<String, dynamic>? data,
  }) async {
    return _inspectionTestPlanRepository.syncInspectionTestPlan(
      data: data,
    );
  }

  Future<Either<MarDescriptionFailure, String>> _onSyncMarDescriptions({
    Map<String, dynamic>? data,
  }) async {
    return _marDescriptionRepository.syncMarDescriptions(
      data: data,
    );
  }

  Future<Either<MarAttachmentFailure, String>> _onSyncMarAttachments({
    Map<String, dynamic>? data,
  }) async {
    return _marAttachmentRepository.syncMarAttachments(
      data: data,
    );
  }

  Future<Either<DesignPhaseFailure, String>> _onSyncDesignPhases({
    Map<String, dynamic>? data,
  }) async {
    return _designPhaseRepository.syncDesignPhases(
      data: data,
    );
  }

  Future<Either<DesignStatusFailure, String>> _onSyncDesignStatuses({
    Map<String, dynamic>? data,
  }) async {
    return _designStatusRepository.syncDesignStatuses(
      data: data,
    );
  }

  Future<Either<DesignRegisterFailure, String>> _onSyncDesignRegisters({
    Map<String, dynamic>? data,
  }) async {
    return _designRegisterRepository.syncDesignRegisters(
      data: data,
    );
  }

  Future<Either<DesignUserFailure, String>> _onSyncDesignUsers({
    Map<String, dynamic>? data,
  }) async {
    return _designUserRepository.syncDesignUsers(
      data: data,
    );
  }

  Future<Either<DocumentTransmissionFailure, String>>
      _onSyncDocumentTransmissions({
    Map<String, dynamic>? data,
  }) async {
    return _documentTransmissionRepository.syncDocumentTransmissions(
      data: data,
    );
  }

  Future<Either<ShopDrawingFailure, String>> _onSyncShopDrawings({
    Map<String, dynamic>? data,
  }) async {
    return _shopDrawingRepository.syncShopDrawings(
      data: data,
    );
  }

  Future<Either<ShopDrawingUserFailure, String>> _onSyncShopDrawingUsers({
    Map<String, dynamic>? data,
  }) async {
    return _shopDrawingUserRepository.syncShopDrawingUsers(
      data: data,
    );
  }

  void _showModalSync(_ShowModalSync event, Emitter<SyncState> emit) {
    emit(
      state.copyWith(
        showModal: event.showModal,
        projectId: event.projectId,
        workspaceId: event.workspaceId,
      ),
    );
  }
}
