using UnityEngine;
using System.Collections;
using System.Collections.Generic;
using System.Runtime.InteropServices;

public enum BeaconRange {
	UNKNOWN,
	FAR,
	NEAR,
	IMMEDIATE
}


public struct Beacon {
	
	public string UUID;
	public int major;
	public int minor;
	public BeaconRange range;
	public int strength;
	public double accuracy;
	
	public Beacon (string _uuid, int _major, int _minor, int _range, int _strength, double _accuracy)
	{
		UUID = _uuid;
		major = _major;
		minor = _minor;
		range = (BeaconRange)_range;
		strength = _strength;
		accuracy = _accuracy;
	}
	
	public string ToString() {
		return "UUID: "+this.UUID+"\nMajor: "+this.major+"\nMinor: "+this.minor+"\nRange: "+this.range.ToString();
	}
	
}
public class iBeaconReceiver : MonoBehaviour {
	public delegate void BeaconRangeChanged(List<Beacon> beacons);
	public static event BeaconRangeChanged BeaconRangeChangedEvent;
	public delegate void BeaconArrived(Beacon beacon);
	public static event BeaconArrived BeaconArrivedEvent;
	public delegate void BeaconOutOfRange(Beacon beacon);
	public static event BeaconOutOfRange BeaconOutOfRangeEvent;
	public string uuid;
	public string region;
	
#if UNITY_ANDROID
	private static AndroidJavaObject plugin;
#endif
	
	private static iBeaconReceiver m_instance;
	
	// assign variables to statics
	void Awake()
	{
		m_instance = this;
	}
	
	#if UNITY_IOS	
	[DllImport ("__Internal")]
	private static extern void InitReceiver(string uuid, string regionIdentifier, bool shouldLog);

	[DllImport ("__Internal")]
	private static extern void StopIOSScan();
	#endif
	private List<Beacon> m_beacons;
	
	void Start () {
		m_beacons = new List<Beacon>();
	}
	
	public static void Init() {
		#if !UNITY_EDITOR
		#if UNITY_IOS
		InitReceiver(m_instance.uuid,m_instance.region,true);
		#elif UNITY_ANDROID
		GetPlugin().Call("Init",true);
		#endif
		#endif
	}
	
	public static void Stop() {
#if !UNITY_EDITOR
#if UNITY_IOS
		Stop();
#elif UNITY_ANDROID
		GetPlugin().Call("Stop");
#endif
#endif
	}
	
	public static void Scan() {
#if !UNITY_EDITOR
#if UNITY_IOS
		InitReceiver(m_instance.uuid,m_instance.region,true);
#elif UNITY_ANDROID
		GetPlugin().Call("Scan");
#endif
#endif		
	}
	
#if UNITY_ANDROID
	public static AndroidJavaObject GetPlugin() {
		if (plugin == null) {
			plugin = new AndroidJavaObject("com.kaasa.ibeacon.BeaconService");
		}
		return plugin;
	}
#endif
	
	public void RangeBeacons(string beacons) {
		if (!string.IsNullOrEmpty(beacons)) {
			string beaconsClean = beacons.Remove(beacons.Length-1); // Get rid of last ;
			string[] beaconsArr = beaconsClean.Split(';');
			List<string> uuids = new List<string>();
			foreach (string beacon in beaconsArr) {
				string[] beaconArr = beacon.Split(',');
				string uuid = beaconArr[0];
				uuids.Add(uuid);
				int major = int.Parse(beaconArr[1]);
				int minor = int.Parse(beaconArr[2]);
				int range = int.Parse(beaconArr[3]);
				int strenght = int.Parse(beaconArr[4]);
				double accuracy = double.Parse(beaconArr[5]);
				Beacon bTmp = new Beacon(uuid,major,minor,range,strenght,accuracy);
				int listident = 0;
				bool removeme = false;
				foreach (Beacon b in m_beacons) {
					if (b.UUID.Equals(uuid)) {
						listident = m_beacons.IndexOf(b);
						removeme = true;
					}
				}
				if (removeme) { // Beacon is already in list, remove it for now and add it again later
					m_beacons.RemoveAt(listident);	
				} else { // this is a new beacon, fire new Beacon Event
					if (BeaconArrivedEvent != null)
						BeaconArrivedEvent(bTmp);
				}
				
				m_beacons.Add(bTmp);
			}
			for (int i = 0; i < m_beacons.Count; i++) {
				if (!uuids.Contains(m_beacons[i].UUID)) { //beacon uuid is not in the list of ranged beacons, delete beacon and fire beacon out of range event 
					if (BeaconOutOfRangeEvent != null)
						BeaconOutOfRangeEvent(m_beacons[i]);
					m_beacons.RemoveAt(i);
				}
			}
			if (BeaconRangeChangedEvent != null)
				BeaconRangeChangedEvent(m_beacons);
		}
	}
}
