// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'error.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CardMindError {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CardMindError);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'CardMindError()';
}


}

/// @nodoc
class $CardMindErrorCopyWith<$Res>  {
$CardMindErrorCopyWith(CardMindError _, $Res Function(CardMindError) __);
}


/// Adds pattern-matching-related methods to [CardMindError].
extension CardMindErrorPatterns on CardMindError {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( CardMindError_Io value)?  io,TResult Function( CardMindError_Sqlite value)?  sqlite,TResult Function( CardMindError_Loro value)?  loro,TResult Function( CardMindError_InvalidArgument value)?  invalidArgument,TResult Function( CardMindError_NotFound value)?  notFound,TResult Function( CardMindError_ProjectionNotConverged value)?  projectionNotConverged,TResult Function( CardMindError_NotImplemented value)?  notImplemented,TResult Function( CardMindError_NotMember value)?  notMember,TResult Function( CardMindError_Internal value)?  internal,required TResult orElse(),}){
final _that = this;
switch (_that) {
case CardMindError_Io() when io != null:
return io(_that);case CardMindError_Sqlite() when sqlite != null:
return sqlite(_that);case CardMindError_Loro() when loro != null:
return loro(_that);case CardMindError_InvalidArgument() when invalidArgument != null:
return invalidArgument(_that);case CardMindError_NotFound() when notFound != null:
return notFound(_that);case CardMindError_ProjectionNotConverged() when projectionNotConverged != null:
return projectionNotConverged(_that);case CardMindError_NotImplemented() when notImplemented != null:
return notImplemented(_that);case CardMindError_NotMember() when notMember != null:
return notMember(_that);case CardMindError_Internal() when internal != null:
return internal(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( CardMindError_Io value)  io,required TResult Function( CardMindError_Sqlite value)  sqlite,required TResult Function( CardMindError_Loro value)  loro,required TResult Function( CardMindError_InvalidArgument value)  invalidArgument,required TResult Function( CardMindError_NotFound value)  notFound,required TResult Function( CardMindError_ProjectionNotConverged value)  projectionNotConverged,required TResult Function( CardMindError_NotImplemented value)  notImplemented,required TResult Function( CardMindError_NotMember value)  notMember,required TResult Function( CardMindError_Internal value)  internal,}){
final _that = this;
switch (_that) {
case CardMindError_Io():
return io(_that);case CardMindError_Sqlite():
return sqlite(_that);case CardMindError_Loro():
return loro(_that);case CardMindError_InvalidArgument():
return invalidArgument(_that);case CardMindError_NotFound():
return notFound(_that);case CardMindError_ProjectionNotConverged():
return projectionNotConverged(_that);case CardMindError_NotImplemented():
return notImplemented(_that);case CardMindError_NotMember():
return notMember(_that);case CardMindError_Internal():
return internal(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( CardMindError_Io value)?  io,TResult? Function( CardMindError_Sqlite value)?  sqlite,TResult? Function( CardMindError_Loro value)?  loro,TResult? Function( CardMindError_InvalidArgument value)?  invalidArgument,TResult? Function( CardMindError_NotFound value)?  notFound,TResult? Function( CardMindError_ProjectionNotConverged value)?  projectionNotConverged,TResult? Function( CardMindError_NotImplemented value)?  notImplemented,TResult? Function( CardMindError_NotMember value)?  notMember,TResult? Function( CardMindError_Internal value)?  internal,}){
final _that = this;
switch (_that) {
case CardMindError_Io() when io != null:
return io(_that);case CardMindError_Sqlite() when sqlite != null:
return sqlite(_that);case CardMindError_Loro() when loro != null:
return loro(_that);case CardMindError_InvalidArgument() when invalidArgument != null:
return invalidArgument(_that);case CardMindError_NotFound() when notFound != null:
return notFound(_that);case CardMindError_ProjectionNotConverged() when projectionNotConverged != null:
return projectionNotConverged(_that);case CardMindError_NotImplemented() when notImplemented != null:
return notImplemented(_that);case CardMindError_NotMember() when notMember != null:
return notMember(_that);case CardMindError_Internal() when internal != null:
return internal(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String field0)?  io,TResult Function( String field0)?  sqlite,TResult Function( String field0)?  loro,TResult Function( String field0)?  invalidArgument,TResult Function( String field0)?  notFound,TResult Function( String entity,  String entityId,  String retryAction)?  projectionNotConverged,TResult Function( String field0)?  notImplemented,TResult Function( String field0)?  notMember,TResult Function( String field0)?  internal,required TResult orElse(),}) {final _that = this;
switch (_that) {
case CardMindError_Io() when io != null:
return io(_that.field0);case CardMindError_Sqlite() when sqlite != null:
return sqlite(_that.field0);case CardMindError_Loro() when loro != null:
return loro(_that.field0);case CardMindError_InvalidArgument() when invalidArgument != null:
return invalidArgument(_that.field0);case CardMindError_NotFound() when notFound != null:
return notFound(_that.field0);case CardMindError_ProjectionNotConverged() when projectionNotConverged != null:
return projectionNotConverged(_that.entity,_that.entityId,_that.retryAction);case CardMindError_NotImplemented() when notImplemented != null:
return notImplemented(_that.field0);case CardMindError_NotMember() when notMember != null:
return notMember(_that.field0);case CardMindError_Internal() when internal != null:
return internal(_that.field0);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String field0)  io,required TResult Function( String field0)  sqlite,required TResult Function( String field0)  loro,required TResult Function( String field0)  invalidArgument,required TResult Function( String field0)  notFound,required TResult Function( String entity,  String entityId,  String retryAction)  projectionNotConverged,required TResult Function( String field0)  notImplemented,required TResult Function( String field0)  notMember,required TResult Function( String field0)  internal,}) {final _that = this;
switch (_that) {
case CardMindError_Io():
return io(_that.field0);case CardMindError_Sqlite():
return sqlite(_that.field0);case CardMindError_Loro():
return loro(_that.field0);case CardMindError_InvalidArgument():
return invalidArgument(_that.field0);case CardMindError_NotFound():
return notFound(_that.field0);case CardMindError_ProjectionNotConverged():
return projectionNotConverged(_that.entity,_that.entityId,_that.retryAction);case CardMindError_NotImplemented():
return notImplemented(_that.field0);case CardMindError_NotMember():
return notMember(_that.field0);case CardMindError_Internal():
return internal(_that.field0);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String field0)?  io,TResult? Function( String field0)?  sqlite,TResult? Function( String field0)?  loro,TResult? Function( String field0)?  invalidArgument,TResult? Function( String field0)?  notFound,TResult? Function( String entity,  String entityId,  String retryAction)?  projectionNotConverged,TResult? Function( String field0)?  notImplemented,TResult? Function( String field0)?  notMember,TResult? Function( String field0)?  internal,}) {final _that = this;
switch (_that) {
case CardMindError_Io() when io != null:
return io(_that.field0);case CardMindError_Sqlite() when sqlite != null:
return sqlite(_that.field0);case CardMindError_Loro() when loro != null:
return loro(_that.field0);case CardMindError_InvalidArgument() when invalidArgument != null:
return invalidArgument(_that.field0);case CardMindError_NotFound() when notFound != null:
return notFound(_that.field0);case CardMindError_ProjectionNotConverged() when projectionNotConverged != null:
return projectionNotConverged(_that.entity,_that.entityId,_that.retryAction);case CardMindError_NotImplemented() when notImplemented != null:
return notImplemented(_that.field0);case CardMindError_NotMember() when notMember != null:
return notMember(_that.field0);case CardMindError_Internal() when internal != null:
return internal(_that.field0);case _:
  return null;

}
}

}

/// @nodoc


class CardMindError_Io extends CardMindError {
  const CardMindError_Io(this.field0): super._();
  

 final  String field0;

/// Create a copy of CardMindError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CardMindError_IoCopyWith<CardMindError_Io> get copyWith => _$CardMindError_IoCopyWithImpl<CardMindError_Io>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CardMindError_Io&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'CardMindError.io(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $CardMindError_IoCopyWith<$Res> implements $CardMindErrorCopyWith<$Res> {
  factory $CardMindError_IoCopyWith(CardMindError_Io value, $Res Function(CardMindError_Io) _then) = _$CardMindError_IoCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$CardMindError_IoCopyWithImpl<$Res>
    implements $CardMindError_IoCopyWith<$Res> {
  _$CardMindError_IoCopyWithImpl(this._self, this._then);

  final CardMindError_Io _self;
  final $Res Function(CardMindError_Io) _then;

/// Create a copy of CardMindError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(CardMindError_Io(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class CardMindError_Sqlite extends CardMindError {
  const CardMindError_Sqlite(this.field0): super._();
  

 final  String field0;

/// Create a copy of CardMindError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CardMindError_SqliteCopyWith<CardMindError_Sqlite> get copyWith => _$CardMindError_SqliteCopyWithImpl<CardMindError_Sqlite>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CardMindError_Sqlite&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'CardMindError.sqlite(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $CardMindError_SqliteCopyWith<$Res> implements $CardMindErrorCopyWith<$Res> {
  factory $CardMindError_SqliteCopyWith(CardMindError_Sqlite value, $Res Function(CardMindError_Sqlite) _then) = _$CardMindError_SqliteCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$CardMindError_SqliteCopyWithImpl<$Res>
    implements $CardMindError_SqliteCopyWith<$Res> {
  _$CardMindError_SqliteCopyWithImpl(this._self, this._then);

  final CardMindError_Sqlite _self;
  final $Res Function(CardMindError_Sqlite) _then;

/// Create a copy of CardMindError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(CardMindError_Sqlite(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class CardMindError_Loro extends CardMindError {
  const CardMindError_Loro(this.field0): super._();
  

 final  String field0;

/// Create a copy of CardMindError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CardMindError_LoroCopyWith<CardMindError_Loro> get copyWith => _$CardMindError_LoroCopyWithImpl<CardMindError_Loro>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CardMindError_Loro&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'CardMindError.loro(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $CardMindError_LoroCopyWith<$Res> implements $CardMindErrorCopyWith<$Res> {
  factory $CardMindError_LoroCopyWith(CardMindError_Loro value, $Res Function(CardMindError_Loro) _then) = _$CardMindError_LoroCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$CardMindError_LoroCopyWithImpl<$Res>
    implements $CardMindError_LoroCopyWith<$Res> {
  _$CardMindError_LoroCopyWithImpl(this._self, this._then);

  final CardMindError_Loro _self;
  final $Res Function(CardMindError_Loro) _then;

/// Create a copy of CardMindError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(CardMindError_Loro(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class CardMindError_InvalidArgument extends CardMindError {
  const CardMindError_InvalidArgument(this.field0): super._();
  

 final  String field0;

/// Create a copy of CardMindError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CardMindError_InvalidArgumentCopyWith<CardMindError_InvalidArgument> get copyWith => _$CardMindError_InvalidArgumentCopyWithImpl<CardMindError_InvalidArgument>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CardMindError_InvalidArgument&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'CardMindError.invalidArgument(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $CardMindError_InvalidArgumentCopyWith<$Res> implements $CardMindErrorCopyWith<$Res> {
  factory $CardMindError_InvalidArgumentCopyWith(CardMindError_InvalidArgument value, $Res Function(CardMindError_InvalidArgument) _then) = _$CardMindError_InvalidArgumentCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$CardMindError_InvalidArgumentCopyWithImpl<$Res>
    implements $CardMindError_InvalidArgumentCopyWith<$Res> {
  _$CardMindError_InvalidArgumentCopyWithImpl(this._self, this._then);

  final CardMindError_InvalidArgument _self;
  final $Res Function(CardMindError_InvalidArgument) _then;

/// Create a copy of CardMindError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(CardMindError_InvalidArgument(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class CardMindError_NotFound extends CardMindError {
  const CardMindError_NotFound(this.field0): super._();
  

 final  String field0;

/// Create a copy of CardMindError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CardMindError_NotFoundCopyWith<CardMindError_NotFound> get copyWith => _$CardMindError_NotFoundCopyWithImpl<CardMindError_NotFound>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CardMindError_NotFound&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'CardMindError.notFound(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $CardMindError_NotFoundCopyWith<$Res> implements $CardMindErrorCopyWith<$Res> {
  factory $CardMindError_NotFoundCopyWith(CardMindError_NotFound value, $Res Function(CardMindError_NotFound) _then) = _$CardMindError_NotFoundCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$CardMindError_NotFoundCopyWithImpl<$Res>
    implements $CardMindError_NotFoundCopyWith<$Res> {
  _$CardMindError_NotFoundCopyWithImpl(this._self, this._then);

  final CardMindError_NotFound _self;
  final $Res Function(CardMindError_NotFound) _then;

/// Create a copy of CardMindError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(CardMindError_NotFound(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class CardMindError_ProjectionNotConverged extends CardMindError {
  const CardMindError_ProjectionNotConverged({required this.entity, required this.entityId, required this.retryAction}): super._();
  

/// 实体类型
 final  String entity;
/// 实体 ID
 final  String entityId;
/// 重试操作建议
 final  String retryAction;

/// Create a copy of CardMindError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CardMindError_ProjectionNotConvergedCopyWith<CardMindError_ProjectionNotConverged> get copyWith => _$CardMindError_ProjectionNotConvergedCopyWithImpl<CardMindError_ProjectionNotConverged>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CardMindError_ProjectionNotConverged&&(identical(other.entity, entity) || other.entity == entity)&&(identical(other.entityId, entityId) || other.entityId == entityId)&&(identical(other.retryAction, retryAction) || other.retryAction == retryAction));
}


@override
int get hashCode => Object.hash(runtimeType,entity,entityId,retryAction);

@override
String toString() {
  return 'CardMindError.projectionNotConverged(entity: $entity, entityId: $entityId, retryAction: $retryAction)';
}


}

/// @nodoc
abstract mixin class $CardMindError_ProjectionNotConvergedCopyWith<$Res> implements $CardMindErrorCopyWith<$Res> {
  factory $CardMindError_ProjectionNotConvergedCopyWith(CardMindError_ProjectionNotConverged value, $Res Function(CardMindError_ProjectionNotConverged) _then) = _$CardMindError_ProjectionNotConvergedCopyWithImpl;
@useResult
$Res call({
 String entity, String entityId, String retryAction
});




}
/// @nodoc
class _$CardMindError_ProjectionNotConvergedCopyWithImpl<$Res>
    implements $CardMindError_ProjectionNotConvergedCopyWith<$Res> {
  _$CardMindError_ProjectionNotConvergedCopyWithImpl(this._self, this._then);

  final CardMindError_ProjectionNotConverged _self;
  final $Res Function(CardMindError_ProjectionNotConverged) _then;

/// Create a copy of CardMindError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? entity = null,Object? entityId = null,Object? retryAction = null,}) {
  return _then(CardMindError_ProjectionNotConverged(
entity: null == entity ? _self.entity : entity // ignore: cast_nullable_to_non_nullable
as String,entityId: null == entityId ? _self.entityId : entityId // ignore: cast_nullable_to_non_nullable
as String,retryAction: null == retryAction ? _self.retryAction : retryAction // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class CardMindError_NotImplemented extends CardMindError {
  const CardMindError_NotImplemented(this.field0): super._();
  

 final  String field0;

/// Create a copy of CardMindError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CardMindError_NotImplementedCopyWith<CardMindError_NotImplemented> get copyWith => _$CardMindError_NotImplementedCopyWithImpl<CardMindError_NotImplemented>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CardMindError_NotImplemented&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'CardMindError.notImplemented(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $CardMindError_NotImplementedCopyWith<$Res> implements $CardMindErrorCopyWith<$Res> {
  factory $CardMindError_NotImplementedCopyWith(CardMindError_NotImplemented value, $Res Function(CardMindError_NotImplemented) _then) = _$CardMindError_NotImplementedCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$CardMindError_NotImplementedCopyWithImpl<$Res>
    implements $CardMindError_NotImplementedCopyWith<$Res> {
  _$CardMindError_NotImplementedCopyWithImpl(this._self, this._then);

  final CardMindError_NotImplemented _self;
  final $Res Function(CardMindError_NotImplemented) _then;

/// Create a copy of CardMindError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(CardMindError_NotImplemented(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class CardMindError_NotMember extends CardMindError {
  const CardMindError_NotMember(this.field0): super._();
  

 final  String field0;

/// Create a copy of CardMindError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CardMindError_NotMemberCopyWith<CardMindError_NotMember> get copyWith => _$CardMindError_NotMemberCopyWithImpl<CardMindError_NotMember>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CardMindError_NotMember&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'CardMindError.notMember(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $CardMindError_NotMemberCopyWith<$Res> implements $CardMindErrorCopyWith<$Res> {
  factory $CardMindError_NotMemberCopyWith(CardMindError_NotMember value, $Res Function(CardMindError_NotMember) _then) = _$CardMindError_NotMemberCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$CardMindError_NotMemberCopyWithImpl<$Res>
    implements $CardMindError_NotMemberCopyWith<$Res> {
  _$CardMindError_NotMemberCopyWithImpl(this._self, this._then);

  final CardMindError_NotMember _self;
  final $Res Function(CardMindError_NotMember) _then;

/// Create a copy of CardMindError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(CardMindError_NotMember(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class CardMindError_Internal extends CardMindError {
  const CardMindError_Internal(this.field0): super._();
  

 final  String field0;

/// Create a copy of CardMindError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CardMindError_InternalCopyWith<CardMindError_Internal> get copyWith => _$CardMindError_InternalCopyWithImpl<CardMindError_Internal>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CardMindError_Internal&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'CardMindError.internal(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $CardMindError_InternalCopyWith<$Res> implements $CardMindErrorCopyWith<$Res> {
  factory $CardMindError_InternalCopyWith(CardMindError_Internal value, $Res Function(CardMindError_Internal) _then) = _$CardMindError_InternalCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$CardMindError_InternalCopyWithImpl<$Res>
    implements $CardMindError_InternalCopyWith<$Res> {
  _$CardMindError_InternalCopyWithImpl(this._self, this._then);

  final CardMindError_Internal _self;
  final $Res Function(CardMindError_Internal) _then;

/// Create a copy of CardMindError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(CardMindError_Internal(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
