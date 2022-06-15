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

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:illinois/service/Analytics.dart';
import 'package:illinois/service/Auth2.dart';
import 'package:illinois/service/Transportation.dart';
import 'package:illinois/ui/wellness/WellnessEightDimensionsPanel.dart';
import 'package:rokwire_plugin/service/localization.dart';
import 'package:rokwire_plugin/service/notification_service.dart';
import 'package:rokwire_plugin/service/styles.dart';
import 'package:rokwire_plugin/ui/widgets/rounded_button.dart';

class WellnessSectionsContentWidget extends StatefulWidget {
  WellnessSectionsContentWidget();

  @override
  State<WellnessSectionsContentWidget> createState() => _WellnessSectionsContentWidgetState();
}

class _WellnessSectionsContentWidgetState extends State<WellnessSectionsContentWidget> implements NotificationsListener {
  Color? _tipColor;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    NotificationService().subscribe(this, [Auth2.notifyLoginChanged]);
    _loadTipColor();
  }

  @override
  void dispose() {
    NotificationService().unsubscribe(this);
    super.dispose();
  }

  void _loadTipColor() {
    _setLoading(true);
    Transportation().loadBusColor(userId: Auth2().accountId, deviceId: Auth2().deviceId).then((activeColor) {
      _tipColor = activeColor;
      _setLoading(false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return _loading ? _buildLoadingContent() : _buildContent();
  }

  Widget _buildContent() {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [_buildTipDescription(), _buildEightDimensionImage(), _buildFooterDescription(), _buildEightDimensionButton()]);
  }

  Widget _buildLoadingContent() {
    return Center(
        child: Column(children: <Widget>[
      Container(height: MediaQuery.of(context).size.height / 5),
      CircularProgressIndicator(),
      Container(height: MediaQuery.of(context).size.height / 5 * 3)
    ]));
  }

  Widget _buildTipDescription() {
    return Container(
        color: (_tipColor ?? Styles().colors!.accentColor3),
        padding: EdgeInsets.all(42),
        child: Text(
            Localization().getStringEx('panel.wellness.sections.description.header.text',
                'Learn to prioritize. Take care of what you can get done today, right now. This will help you be a better time manager and reduce the risk of procrastination.'),
            textAlign: TextAlign.center,
            style: TextStyle(color: Styles().colors!.white, fontSize: 22, fontFamily: Styles().fontFamilies!.extraBold)));
  }

  Widget _buildEightDimensionImage() {
    //TBD: DD - image resource for 8 dimension
    return Container();
  }

  Widget _buildFooterDescription() {
    return Padding(
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
                style: TextStyle(color: Styles().colors!.fillColorPrimary, fontSize: 16, fontFamily: Styles().fontFamilies!.regular),
                children: [
                  TextSpan(
                      text: Localization().getStringEx('panel.wellness.sections.description.footer.wellness.text', 'Wellness '),
                      style: TextStyle(fontFamily: Styles().fontFamilies!.bold)),
                  TextSpan(
                      text: Localization().getStringEx('panel.wellness.sections.description.footer.description.text',
                          'is a state of optimal well-being that is oriented toward maximizing an individual\'s potential. This is a life-long process of moving towards enhancing your ')),
                  TextSpan(
                      text: Localization().getStringEx('panel.wellness.sections.description.footer.dimensions.text',
                          'physical, mental, environmental, financial, spiritual, vocational, emotional and social wellness.'),
                      style: TextStyle(fontFamily: Styles().fontFamilies!.bold))
                ])));
  }

  Widget _buildEightDimensionButton() {
    return RoundedButton(
        label: Localization().getStringEx('panel.wellness.sections.dimensions.button', 'Learn more about the 8 dimensions'),
        textStyle: TextStyle(fontSize: 14),
        rightIcon: Image.asset('images/external-link.png'),
        rightIconPadding: EdgeInsets.only(left: 4, right: 6),
        onTap: _onTapEightDimensions);
  }

  void _onTapEightDimensions() {
    Analytics().logSelect(target: "Wellness 8 Dimensions");
    Navigator.of(context).push(CupertinoPageRoute(builder: (context) => WellnessEightDimensionsPanel()));
  }

  void _setLoading(bool loading) {
    _loading = loading;
    if (mounted) {
      setState(() {});
    }
  }

  // Notifications Listener

  @override
  void onNotification(String name, param) {
    if (name == Auth2.notifyLoginChanged) {
      _loadTipColor();
    }
  }
}