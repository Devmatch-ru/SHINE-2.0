import 'package:flutter_bloc/flutter_bloc.dart';
import 'role_state.dart';

class RoleCubit extends Cubit<RoleState> {
  RoleCubit() : super(RoleInitial());

  void selectHost() => emit(RoleHost());
  void selectClient() => emit(RoleClient());
  void reset() => emit(RoleInitial());
}
