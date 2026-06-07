// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'dashboard_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$DashboardState {
  int get timeRange => throw _privateConstructorUsedError;
  String? get selectedTeamId => throw _privateConstructorUsedError;
  DashboardListFilter get listFilter => throw _privateConstructorUsedError;

  /// Create a copy of DashboardState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DashboardStateCopyWith<DashboardState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DashboardStateCopyWith<$Res> {
  factory $DashboardStateCopyWith(
          DashboardState value, $Res Function(DashboardState) then) =
      _$DashboardStateCopyWithImpl<$Res, DashboardState>;
  @useResult
  $Res call(
      {int timeRange, String? selectedTeamId, DashboardListFilter listFilter});
}

/// @nodoc
class _$DashboardStateCopyWithImpl<$Res, $Val extends DashboardState>
    implements $DashboardStateCopyWith<$Res> {
  _$DashboardStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DashboardState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? timeRange = null,
    Object? selectedTeamId = freezed,
    Object? listFilter = null,
  }) {
    return _then(_value.copyWith(
      timeRange: null == timeRange
          ? _value.timeRange
          : timeRange // ignore: cast_nullable_to_non_nullable
              as int,
      selectedTeamId: freezed == selectedTeamId
          ? _value.selectedTeamId
          : selectedTeamId // ignore: cast_nullable_to_non_nullable
              as String?,
      listFilter: null == listFilter
          ? _value.listFilter
          : listFilter // ignore: cast_nullable_to_non_nullable
              as DashboardListFilter,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$DashboardStateImplCopyWith<$Res>
    implements $DashboardStateCopyWith<$Res> {
  factory _$$DashboardStateImplCopyWith(_$DashboardStateImpl value,
          $Res Function(_$DashboardStateImpl) then) =
      __$$DashboardStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int timeRange, String? selectedTeamId, DashboardListFilter listFilter});
}

/// @nodoc
class __$$DashboardStateImplCopyWithImpl<$Res>
    extends _$DashboardStateCopyWithImpl<$Res, _$DashboardStateImpl>
    implements _$$DashboardStateImplCopyWith<$Res> {
  __$$DashboardStateImplCopyWithImpl(
      _$DashboardStateImpl _value, $Res Function(_$DashboardStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of DashboardState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? timeRange = null,
    Object? selectedTeamId = freezed,
    Object? listFilter = null,
  }) {
    return _then(_$DashboardStateImpl(
      timeRange: null == timeRange
          ? _value.timeRange
          : timeRange // ignore: cast_nullable_to_non_nullable
              as int,
      selectedTeamId: freezed == selectedTeamId
          ? _value.selectedTeamId
          : selectedTeamId // ignore: cast_nullable_to_non_nullable
              as String?,
      listFilter: null == listFilter
          ? _value.listFilter
          : listFilter // ignore: cast_nullable_to_non_nullable
              as DashboardListFilter,
    ));
  }
}

/// @nodoc

class _$DashboardStateImpl implements _DashboardState {
  const _$DashboardStateImpl(
      {this.timeRange = 0,
      this.selectedTeamId,
      this.listFilter = DashboardListFilter.all});

  @override
  @JsonKey()
  final int timeRange;
  @override
  final String? selectedTeamId;
  @override
  @JsonKey()
  final DashboardListFilter listFilter;

  @override
  String toString() {
    return 'DashboardState(timeRange: $timeRange, selectedTeamId: $selectedTeamId, listFilter: $listFilter)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DashboardStateImpl &&
            (identical(other.timeRange, timeRange) ||
                other.timeRange == timeRange) &&
            (identical(other.selectedTeamId, selectedTeamId) ||
                other.selectedTeamId == selectedTeamId) &&
            (identical(other.listFilter, listFilter) ||
                other.listFilter == listFilter));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, timeRange, selectedTeamId, listFilter);

  /// Create a copy of DashboardState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DashboardStateImplCopyWith<_$DashboardStateImpl> get copyWith =>
      __$$DashboardStateImplCopyWithImpl<_$DashboardStateImpl>(
          this, _$identity);
}

abstract class _DashboardState implements DashboardState {
  const factory _DashboardState(
      {final int timeRange,
      final String? selectedTeamId,
      final DashboardListFilter listFilter}) = _$DashboardStateImpl;

  @override
  int get timeRange;
  @override
  String? get selectedTeamId;
  @override
  DashboardListFilter get listFilter;

  /// Create a copy of DashboardState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DashboardStateImplCopyWith<_$DashboardStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
