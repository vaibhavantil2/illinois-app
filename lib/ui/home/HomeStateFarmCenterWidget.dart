/*
 * Copyright 2020 Board of Trustees of the University of Illinois.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:illinois/service/Analytics.dart';
import 'package:illinois/service/Config.dart';
import 'package:illinois/service/NativeCommunicator.dart';
import 'package:illinois/ui/home/HomePanel.dart';
import 'package:illinois/ui/home/HomeWidgets.dart';
import 'package:illinois/ui/parking/ParkingEventsPanel.dart';
import 'package:illinois/ui/polls/CreateStadiumPollPanel.dart';
import 'package:rokwire_plugin/service/localization.dart';

class HomeStateFarmCenterWidget extends StatefulWidget {

  final String? favoriteId;
  final StreamController<String>? updateController;

  const HomeStateFarmCenterWidget({Key? key, this.favoriteId, this.updateController}) : super(key: key);

  static Widget handle({String? favoriteId, HomeDragAndDropHost? dragAndDropHost, int? position}) =>
    HomeHandleWidget(favoriteId: favoriteId, dragAndDropHost: dragAndDropHost, position: position,
      title: title,
    );

  static String get title => Localization().getStringEx('widget.home.state_farm_center.header.title',  'State Farm Center');

  @override
  State<StatefulWidget> createState() => _HomeStateFarmCenterWidgetState();
}

class _HomeStateFarmCenterWidgetState extends HomeCompoundWidgetState<HomeStateFarmCenterWidget> {

  @override String? get favoriteId => widget.favoriteId;
  @override String? get title => HomeStateFarmCenterWidget.title;
  @override String? get emptyTitle => Localization().getStringEx("widget.home.state_farm_center.text.empty", "Whoops! Nothing to see here.");
  @override String? get emptyMessage => Localization().getStringEx("widget.home.state_farm_center.text.empty.description", "Tap the \u2606 on items in State Farm Center so you can quickly find them here.");

  @override
  Widget? widgetFromCode(String? code) {
    if (code == 'parking') {
      return HomeCommandButton(
        title: Localization().getStringEx('widget.home.state_farm_center.parking.button.title', 'Parking'),
        description: Localization().getStringEx('widget.home.state_farm_center.parking.button.description', 'Lorem ipsum dolor sit amet, consectetur adipiscing elit.'),
        favorite: HomeFavorite(code, category: widget.favoriteId),
        onTap: _onParking,
      );
    }
    else if (code == 'wayfinding') {
      return HomeCommandButton(
        title: Localization().getStringEx('widget.home.state_farm_center.wayfinding.button.title', 'Wayfinding'),
        description: Localization().getStringEx('widget.home.state_farm_center.wayfinding.button.description', 'Aenean commodo faucibus sem, id finibus tortor rutrum consectetur.'),
        favorite: HomeFavorite(code, category: widget.favoriteId),
        onTap: _onWayfinding,
      );
    }
    else if (code == 'create_stadium_poll') {
      return HomeCommandButton(
        title: Localization().getStringEx('widget.home.state_farm_center.create_stadium_poll.button.title', 'Create Stadium Poll'),
        description: Localization().getStringEx('widget.home.state_farm_center.create_stadium_poll.button.description', 'Vivamus aliquam hendrerit risus eget accumsan.'),
        favorite: HomeFavorite(code, category: widget.favoriteId),
        onTap: _onCreateStadiumPoll,
      );
    }
    else {
      return null;
    }
  }

  void _onParking() {
    Analytics().logSelect(target: "HomeStateFarmCenterWidget: Parking");
    Navigator.push(context, CupertinoPageRoute(builder: (context) => ParkingEventsPanel()));
  }

  void _onWayfinding() {
    Analytics().logSelect(target: "HomeStateFarmCenterWidget: Wayfinding");
    NativeCommunicator().launchMap(target: {
      'latitude': Config().stateFarmWayfinding['latitude'],
      'longitude': Config().stateFarmWayfinding['longitude'],
      'zoom': Config().stateFarmWayfinding['zoom'],
    });
  }

  void _onCreateStadiumPoll() {
    Analytics().logSelect(target: "HomeStateFarmCenterWidget: Create Stadium Poll");
    CreateStadiumPollPanel.present(context);
  }

}
