
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_geofire/flutter_geofire.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ride_app_driver/global/global_var.dart';
import 'package:ride_app_driver/methods/map_theme_methods.dart';
import 'package:ride_app_driver/pushNotification/push_notification_system.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  final Completer<GoogleMapController> googleMapCompleterController = Completer<GoogleMapController>();
  GoogleMapController? controllerGoogleMap;

  Position? currentPositionOfDriver;

  Color colorToShow = Colors.green;
  String titleToShow = "GO ONLINE NOW";
  bool isDriverAvailable = false;

  DatabaseReference? newTripRequestReference;

  MapThemeMethods themeMethods = MapThemeMethods();

  getCurrentLiveLocationOfDriver() async{
    Position positionOfUser = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.bestForNavigation);
    currentPositionOfDriver = positionOfUser;
    driverCurrentPosition = currentPositionOfDriver;

    LatLng positionOfUserInLatLng = LatLng(currentPositionOfDriver!.latitude, currentPositionOfDriver!.longitude);

    CameraPosition cameraPosition = CameraPosition(target: positionOfUserInLatLng, zoom: 14,);
    controllerGoogleMap!.animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
  }

  goOnlineNow(){
    /* all drivers who are available for new trip request */
    Geofire.initialize("onlineDrivers");
    Geofire.setLocation(FirebaseAuth.instance.currentUser!.uid, currentPositionOfDriver!.latitude, currentPositionOfDriver!.latitude,);
    newTripRequestReference = FirebaseDatabase.instance.ref().child("drivers").child(FirebaseAuth.instance.currentUser!.uid).child("newTripStatus");
    newTripRequestReference!.set("waiting");
    newTripRequestReference!.onValue.listen((event) {});
  }

  setAndGetLocationUpdates(){
    positionStreamHomePage = Geolocator.getPositionStream().listen((Position position) {
      currentPositionOfDriver = position;
      if(isDriverAvailable==true){
        Geofire.setLocation(FirebaseAuth.instance.currentUser!.uid, currentPositionOfDriver!.latitude, currentPositionOfDriver!.longitude);
      }
      LatLng positionLatLng = LatLng(position.latitude, position.longitude,);
      controllerGoogleMap!.animateCamera(CameraUpdate.newLatLng(positionLatLng,),);
    });
  }

  goOfflineNow(){
    /** stop sharing live location **/
    Geofire.removeLocation(FirebaseAuth.instance.currentUser!.uid,);

    /** stop listening to the newTripStatus **/
    newTripRequestReference!.onDisconnect();
    newTripRequestReference!.remove();
    newTripRequestReference = null;
  }

  initializePushNotificationSystem(){
    PushNotificationSystem notificationSystem = PushNotificationSystem();
    notificationSystem.generateDeviceRegistrationToken();
    notificationSystem.startListeningForNewNotification(context);
  }

  retrieveCurrentDriverInfo()async{
    await FirebaseDatabase.instance.ref().child("drivers").child(FirebaseAuth.instance.currentUser!.uid).once().then((snap){
      driverName = (snap.snapshot.value as Map)["name"];
      driverPhone = (snap.snapshot.value as Map)["phone"];
      driverPhoto = (snap.snapshot.value as Map)["photo"];
      carColor = (snap.snapshot.value as Map)["car_details"]["carColor"];
      carModel = (snap.snapshot.value as Map)["car_details"]["carModel"];
      carNumber = (snap.snapshot.value as Map)["car_details"]["carNumber"];
    });
    initializePushNotificationSystem();
  }

  @override
  void initState() {
    super.initState();
    retrieveCurrentDriverInfo();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Stack(
          children: [
            /** google map **/
            GoogleMap(
              padding: const EdgeInsets.only(top: 135,),
              initialCameraPosition: googlePlexInitialPosition,
              mapType: MapType.normal,
              myLocationEnabled: true,
              onMapCreated: (GoogleMapController googleMapController){
                controllerGoogleMap = googleMapController;
                themeMethods.updateMapTheme(controllerGoogleMap!);
      
                googleMapCompleterController.complete(controllerGoogleMap);
      
                getCurrentLiveLocationOfDriver();
              },
            ),
      
            Container(height: 100, width: double.infinity, color: Colors.black54,),
      
            /** go online/offline button **/
            Positioned(
              left: 0,
              right: 0,
              top: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: (){
                      showModalBottomSheet(
                        context: context,
                        isDismissible: false,
                        builder: (BuildContext context){
                          return Container(
                            decoration: const BoxDecoration(
                              color: Colors.black87,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey,
                                  blurRadius: 5.0,
                                  spreadRadius: 0.5,
                                  offset: Offset(0.7, 0.7),
                                ),
                              ],
                            ),
                            height: 220,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18,),
                              child: Column(
                                children: [
                                  const SizedBox(height: 11,),
      
                                  Text((!isDriverAvailable) ? "GO ONLINE NOW" : "GO OFFLINE NOW", style: const TextStyle(fontSize: 22, color: Colors.white70, fontWeight: FontWeight.bold,),),
      
                                  const SizedBox(height: 21,),
      
                                  Text(
                                    (!isDriverAvailable)
                                    ? "You are about to go online, you will become available to receive trip request from users."
                                    : "You are about to go offline, you will stop receiving now trip requests from users.",
                                    style: const TextStyle(color: Colors.white30,),
                                  ),
      
                                  const SizedBox(height: 25,),
      
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: (){
                                            Navigator.pop(context);
                                          },
                                          child: const Text("BACK"),
                                        ),
                                      ),
      
                                      const SizedBox(width: 16,),
      
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: (){
                                            if(!isDriverAvailable){
                                              /** go online **/
                                              goOnlineNow();
      
                                              /** get drivers location **/
                                              setAndGetLocationUpdates();
      
                                              Navigator.pop(context);
                                              setState(() {
                                                colorToShow = Colors.purple;
                                                titleToShow = "GO OFFLINE NOW";
                                                isDriverAvailable = true;
                                              });
                                            }
                                            else{
                                              /** go offline **/
                                              goOfflineNow();
      
                                              Navigator.pop(context);
                                              setState(() {
                                                colorToShow = Colors.green;
                                                titleToShow = "GO ONLINE NOW";
                                                isDriverAvailable = false;
                                              });
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: (titleToShow=="GO ONLINE NOW") ? Colors.green : Colors.purple,
                                          ),
                                          child: const Text("CONFIRM"),
                                        ),
                                      ),
      
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: colorToShow,),
                    child: Text(titleToShow,),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
