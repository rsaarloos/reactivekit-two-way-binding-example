//
//  ViewController.swift
//  twowaybindingexample
//
//  Created by Rogier Saarloos on 12/04/16.
//  Copyright © 2016 Saarloos. All rights reserved.
//

import UIKit
import ReactiveKit
import ReactiveUIKit
import AFDateHelper

class ViewController: UIViewController {

    @IBOutlet weak var datePicker: UIDatePicker!
    @IBOutlet weak var currentDateLabel: UILabel!
    @IBOutlet weak var setTodayButton: UIButton!
    
    var selectedDate = PushStream<NSDate>()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // When the selected date is changed update the label showing the date
        selectedDate.map{ date in
            return "Selected date: \(date.toString(dateStyle: .FullStyle, timeStyle: .NoStyle))"
        }.bindTo(currentDateLabel.rText)
        
        // Changes to the date picked should reflect in the selected date stream
        datePicker.rDate.bindTo(selectedDate)
        
        // Changes to the selected date should reflect in the date picker
        selectedDate.bindTo(datePicker.rDate)
        
        // When the button is tapped set the date to today
        setTodayButton.rTap.map{
            return NSDate()
        }.bindTo(selectedDate)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

